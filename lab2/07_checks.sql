-- Проверки через обычные SELECT: количества, статусы и нетривиальные ситуации.
SELECT 'patients' AS table_name, COUNT(*) AS row_count FROM patients
UNION ALL SELECT 'doctors', COUNT(*) FROM doctors
UNION ALL SELECT 'specialties', COUNT(*) FROM specialties
UNION ALL SELECT 'services', COUNT(*) FROM services
UNION ALL SELECT 'appointments', COUNT(*) FROM appointments;

SELECT (SELECT COUNT(*) FROM patients)
     + (SELECT COUNT(*) FROM doctors)
     + (SELECT COUNT(*) FROM specialties)
     + (SELECT COUNT(*) FROM services)
     + (SELECT COUNT(*) FROM appointments) AS total_rows;

SELECT status, COUNT(*) AS appointment_count
FROM appointments
GROUP BY status
ORDER BY status;

WITH months(month, next_month) AS (
    VALUES
        (TIMESTAMPTZ '2026-09-01 00:00:00+03', TIMESTAMPTZ '2026-10-01 00:00:00+03'),
        (TIMESTAMPTZ '2026-10-01 00:00:00+03', TIMESTAMPTZ '2026-11-01 00:00:00+03'),
        (TIMESTAMPTZ '2026-11-01 00:00:00+03', TIMESTAMPTZ '2026-12-01 00:00:00+03')
)
SELECT m.month, COUNT(a.appointment_id) AS appointment_count
FROM months AS m
LEFT JOIN appointments AS a ON a.starts_at >= m.month AND a.starts_at < m.next_month
GROUP BY m.month
ORDER BY m.month;

-- Повторные обращения.
SELECT patient_id, COUNT(*) AS appointment_count
FROM appointments
GROUP BY patient_id
HAVING COUNT(*) > 1;

-- Пациенты без приёмов.
SELECT p.patient_id, p.full_name
FROM patients AS p
WHERE NOT EXISTS (SELECT 1 FROM appointments AS a WHERE a.patient_id = p.patient_id);

-- Врачи без приёмов.
SELECT d.doctor_id, d.full_name
FROM doctors AS d
WHERE NOT EXISTS (SELECT 1 FROM appointments AS a WHERE a.doctor_id = d.doctor_id);

SELECT COUNT(*) AS free_services FROM services WHERE price = 0;
SELECT COUNT(*) AS free_appointments FROM appointments WHERE charged_price = 0;

-- Ожидаем ноль несовпадений специальностей.
SELECT COUNT(*) AS specialty_mismatches
FROM appointments AS a
JOIN doctors AS d ON d.doctor_id = a.doctor_id
JOIN services AS s ON s.service_id = a.service_id
WHERE d.specialty_id <> s.specialty_id;
