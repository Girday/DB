-- 2.2.1. Сколько записей каждого статуса у каждого врача, включая врачей без записей.
-- COUNT(a.appointment_id) даёт 0 для пустого соединения; COUNT(*) дал бы 1.
SELECT d.doctor_id, d.full_name AS doctor, a.status,
       COUNT(a.appointment_id) AS appointment_count
FROM doctors AS d
LEFT JOIN appointments AS a ON a.doctor_id = d.doctor_id
GROUP BY d.doctor_id, d.full_name, a.status
ORDER BY d.doctor_id, a.status;

-- 2.2.2. Пациенты, у которых стоимость оказанных услуг не менее 3000 рублей.
-- Отменённые и запланированные приёмы не относятся к оказанным услугам.
SELECT p.patient_id, p.medical_record_number, p.full_name,
       COUNT(*) AS completed_count,
       SUM(a.charged_price) AS completed_amount,
       ROUND(AVG(a.charged_price), 2) AS average_price,
       MIN(a.charged_price) AS min_price,
       MAX(a.charged_price) AS max_price
FROM patients AS p
JOIN appointments AS a ON a.patient_id = p.patient_id
WHERE a.status = 'completed'
GROUP BY p.patient_id, p.medical_record_number, p.full_name
HAVING SUM(a.charged_price) >= 3000
ORDER BY completed_amount DESC, p.patient_id;

-- 2.2.3. Сравнение месяцев и специальностей по завершённым приёмам.
-- Три календарных интервала заданы явно, с московским смещением +03.
WITH months(month, next_month) AS (
    VALUES
        (TIMESTAMPTZ '2026-09-01 00:00:00+03', TIMESTAMPTZ '2026-10-01 00:00:00+03'),
        (TIMESTAMPTZ '2026-10-01 00:00:00+03', TIMESTAMPTZ '2026-11-01 00:00:00+03'),
        (TIMESTAMPTZ '2026-11-01 00:00:00+03', TIMESTAMPTZ '2026-12-01 00:00:00+03')
)
SELECT m.month,
       sp.name AS specialty,
       COUNT(*) AS completed_count,
       SUM(a.charged_price) AS completed_amount,
       ROUND(AVG(a.charged_price), 2) AS average_price
FROM months AS m
JOIN appointments AS a ON a.starts_at >= m.month AND a.starts_at < m.next_month
JOIN services AS s ON s.service_id = a.service_id
JOIN specialties AS sp ON sp.specialty_id = s.specialty_id
WHERE a.status = 'completed'
GROUP BY m.month, sp.specialty_id, sp.name
ORDER BY m.month, sp.name;
