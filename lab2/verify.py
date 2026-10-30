#!/usr/bin/env python3
"""Проверка ЛР2 в собственном временном PostgreSQL; рабочая база не используется."""

import csv
import io
import json
import re
import subprocess
import time
import uuid
from collections import defaultdict
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
CONTAINER = "db-lab2-verify-" + uuid.uuid4().hex[:10]
TABLES = ("patients", "specialties", "doctors", "services", "appointments")


def docker(*args, input=None, check=True):
    return subprocess.run(
        ["docker", *args], input=input, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=check,
    )


def execute(sql, check=True, quiet=True):
    return docker(
        "exec", "-i", CONTAINER, "psql", "-X", "-U", "postgres", "-d", "lab2_check",
        "-v", "ON_ERROR_STOP=1", "-qAt" if quiet else "-At", "-f", "-", input=sql, check=check,
    )


def query(sql, timezone="Europe/Moscow"):
    result = execute(
        f"SET TIME ZONE '{timezone}';\n"
        "SELECT COALESCE(json_agg(result), '[]'::json) FROM (\n"
        + sql.strip().rstrip(";") + "\n) AS result;"
    )
    return json.loads(result.stdout, parse_float=Decimal)


def snapshot():
    return {t: query(f"SELECT * FROM {t} ORDER BY 1") for t in TABLES}


def rounded(value):
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def verify_queries(results, data):
    patients = {p["patient_id"]: p for p in data["patients"]}
    doctors = {d["doctor_id"]: d for d in data["doctors"]}
    services = {s["service_id"]: s for s in data["services"]}
    specialties = {s["specialty_id"]: s for s in data["specialties"]}
    appointments = data["appointments"]
    completed = [a for a in appointments if a["status"] == "completed"]
    ids = lambda rows, key: {r[key] for r in rows}

    expected = {a["appointment_id"] for a in appointments if a["starts_at"].startswith("2026-10")}
    assert ids(results["2.1.1"], "appointment_id") == expected
    assert len(results["2.1.1"]) == len(expected), "JOIN размножил приёмы"
    for row in results["2.1.1"]:
        a = next(a for a in appointments if a["appointment_id"] == row["appointment_id"])
        assert row["charged_price"] == a["charged_price"]
        assert row["current_price"] == services[a["service_id"]]["price"]

    assert ids(results["2.1.2"], "doctor_id") == set(doctors) - ids(appointments, "doctor_id")
    assert all(r["appointment_id"] is None for r in results["2.1.2"])
    expected = {
        a["patient_id"] for a in appointments
        if a["status"] == "scheduled" and a["charged_price"] > 0
        and a["starts_at"].startswith("2026-11")
        and specialties[services[a["service_id"]]["specialty_id"]]["name"] == "Неврология"
    }
    assert ids(results["2.1.3"], "patient_id") == expected
    assert len(results["2.1.3"]) == len(expected)

    counts = defaultdict(int)
    for d in doctors:
        own = [a for a in appointments if a["doctor_id"] == d]
        if not own:
            counts[d, None] = 0
        for a in own:
            counts[d, a["status"]] += 1
    assert {(r["doctor_id"], r["status"]): r["appointment_count"] for r in results["2.2.1"]} == counts

    by_patient = defaultdict(list)
    by_month = defaultdict(list)
    for a in completed:
        by_patient[a["patient_id"]].append(a["charged_price"])
        sp = specialties[services[a["service_id"]]["specialty_id"]]["name"]
        by_month[a["starts_at"][:7] + "-01", sp].append(a["charged_price"])
    expected = {p for p, values in by_patient.items() if sum(values) >= 3000}
    assert ids(results["2.2.2"], "patient_id") == expected
    for r in results["2.2.2"]:
        values = by_patient[r["patient_id"]]
        assert (r["completed_count"], r["completed_amount"], r["average_price"], r["min_price"], r["max_price"]) == (
            len(values), sum(values), rounded(sum(values) / len(values)), min(values), max(values)
        )
    assert {(r["month"][:7] + "-01", r["specialty"]) for r in results["2.2.3"]} == set(by_month)
    for r in results["2.2.3"]:
        values = by_month[r["month"][:7] + "-01", r["specialty"]]
        assert (r["completed_count"], r["completed_amount"], r["average_price"]) == (
            len(values), sum(values), rounded(sum(values) / len(values))
        )

    expected = set()
    for s in services.values():
        peers = [other["price"] for other in services.values() if other["specialty_id"] == s["specialty_id"]]
        if s["price"] > sum(peers) / len(peers):
            expected.add(s["service_id"])
    assert ids(results["3.1"], "service_id") == expected
    assert ids(results["3.2"], "patient_id") == {a["patient_id"] for a in completed if a["charged_price"] > 0}
    assert ids(results["3.3"], "patient_id") == {
        a["patient_id"] for a in appointments if a["status"] == "cancelled"
    } - ids(completed, "patient_id")
    assert ids(results["3.4"], "patient_id") == set(patients)
    for r in results["3.4"]:
        dates = [a["starts_at"] for a in completed if a["patient_id"] == r["patient_id"]]
        assert r["last_completed_at"] == (max(dates) if dates else None)

    assert ids(results["4"], "specialty_id") == set(specialties)
    for r in results["4"]:
        own = [a for a in appointments if services[a["service_id"]]["specialty_id"] == r["specialty_id"]]
        done = [a for a in own if a["status"] == "completed"]
        amount = sum((a["charged_price"] for a in done), Decimal(0))
        assert r["appointment_count"] == len(own)
        assert r["completed_count"] == len(done)
        assert r["completed_amount"] == amount
        assert r["cancelled_count"] == sum(a["status"] == "cancelled" for a in own)
        assert r["scheduled_count"] == sum(a["status"] == "scheduled" for a in own)
        assert r["average_completed_price"] == (rounded(amount / len(done)) if done else None)
        expected_percent = rounded(Decimal(100) * r["cancelled_count"] / len(own)) if own else None
        assert r["cancellation_percent"] == expected_percent


def main():
    created = False
    try:
        docker("run", "--detach", "--rm", "--name", CONTAINER, "--network", "none",
               "--tmpfs", "/var/lib/postgresql/data:rw", "-e", "POSTGRES_HOST_AUTH_METHOD=trust",
               "-e", "POSTGRES_DB=lab2_check", "postgres:17.11", "-c", "timezone=Europe/Moscow")
        created = True
        for _ in range(60):
            # Во время initdb временный сервер принимает Unix-сокет, но ещё не TCP.
            if docker("exec", CONTAINER, "psql", "-h", "127.0.0.1", "-U", "postgres",
                      "-d", "lab2_check", "-Atc", "SELECT 1", check=False).returncode == 0:
                break
            time.sleep(0.25)
        else:
            raise RuntimeError("Временный PostgreSQL не запустился")

        execute((ROOT / "lab1/schema.sql").read_text())
        execute((ROOT / "lab1/data.sql").read_text())
        original = snapshot()
        execute((ROOT / "lab2/01_data.sql").read_text())
        data = snapshot()
        assert [len(data[t]) for t in TABLES] == [24, 3, 8, 12, 80]
        for t in TABLES:
            pk = next(iter(original[t][0]))
            current = {r[pk]: r for r in data[t]}
            assert all(current[r[pk]] == r for r in original[t]), f"Изменены исходные строки {t}"
        execute((ROOT / "lab2/07_checks.sql").read_text())

        statements = {}
        for name in ("03_joins.sql", "04_aggregates.sql", "05_subqueries.sql", "06_report.sql"):
            source = (ROOT / "lab2" / name).read_text()
            parts = re.split(r"^-- (2\.1\.\d|2\.2\.\d|3\.\d|4)\. ", source, flags=re.M)
            for i in range(1, len(parts), 2):
                # Возвращаем первую строку описания в комментарий.
                statements[parts[i]] = "-- " + parts[i + 1]
        assert len(statements) == 11
        results = {key: query(sql) for key, sql in statements.items()}
        assert all(results.values()), "Каждый запрос должен иметь содержательный результат"
        verify_queries(results, data)

        dml = execute((ROOT / "lab2/02_dml.sql").read_text(), quiet=False)
        assert snapshot() == data, "ROLLBACK не восстановил строки"
        # Проверяем число строк каждого DML-действия, а не только итоговый откат.
        assert re.findall(r"^(?:INSERT 0|UPDATE|DELETE) \d+$", dml.stdout, re.M) == [
            "INSERT 0 1", "INSERT 0 2", "UPDATE 1", "UPDATE 2", "DELETE 1"
        ]

        repeat = execute((ROOT / "lab2/01_data.sql").read_text(), check=False)
        assert repeat.returncode != 0, "Повторную загрузку должен остановить UNIQUE"
        assert snapshot() == data, "Повторная загрузка оставила частичные изменения"

        # Пустая специальность и незавершённые приёмы проверяют деление на ноль/NULL.
        execute("INSERT INTO specialties(name) VALUES ('Без записей');")
        execute("UPDATE appointments SET status = 'scheduled' WHERE service_id IN "
                "(SELECT service_id FROM services WHERE specialty_id = "
                "(SELECT specialty_id FROM specialties WHERE name = 'Неврология'));")
        edge = {key: query(sql) for key, sql in statements.items()}
        verify_queries(edge, snapshot())
        # Пограничная запись: 1 ноября по Москве, но ещё 31 октября по UTC.
        execute("INSERT INTO appointments(patient_id,doctor_id,service_id,starts_at,charged_price,status) "
                "SELECT p.patient_id,d.doctor_id,s.service_id,'2026-11-01 00:30:00+03',s.price,'completed' "
                "FROM patients p CROSS JOIN doctors d JOIN services s USING (specialty_id) "
                "WHERE p.medical_record_number='ЛР2-001' AND d.full_name='Роман Олегович Белов' "
                "AND s.name='Расширенная консультация терапевта';")
        for key in ("4",):
            assert query(statements[key], "Pacific/Honolulu") == query(statements[key])
        def month_metrics(timezone):
            return [{k: v for k, v in row.items() if k != "month"}
                    for row in query(statements["2.2.3"], timezone)]
        assert month_metrics("Pacific/Honolulu") == month_metrics("Europe/Moscow")
        for key, id_key in (("2.1.1", "appointment_id"), ("2.1.3", "patient_id")):
            assert {r[id_key] for r in query(statements[key], "Pacific/Honolulu")} == {
                r[id_key] for r in query(statements[key])
            }

        output = ROOT / "lab2/results"
        output.mkdir(exist_ok=True)
        for key, rows in results.items():
            stream = io.StringIO()
            writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
            writer.writeheader()
            writer.writerows(rows)
            (output / (key + ".csv")).write_text(stream.getvalue())
        print("Проверено: 127 строк, исходные данные сохранены; все 11 запросов совпали")
        print("с независимыми расчётами Python; DML откатился; повторная загрузка безопасно")
        print("отклонена; пустые группы, отсутствие завершённых приёмов и часовой пояс проверены.")
        print("Результаты исходного набора: lab2/results/*.csv")
    finally:
        if created:
            docker("stop", CONTAINER, check=False)


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as error:
        raise SystemExit(error.stderr) from error
