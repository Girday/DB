-- 2.1.1. Подробный журнал приёмов за октябрь: пациент, врач, услуга, специальность.
-- Цена записи отличается от текущего тарифа: это отдельные показатели.
SELECT a.appointment_id, a.starts_at, a.status,
       p.medical_record_number, p.full_name AS patient,
       d.full_name AS doctor, sp.name AS specialty,
       s.name AS service, a.charged_price, s.price AS current_price
FROM appointments AS a
JOIN patients AS p ON p.patient_id = a.patient_id
JOIN doctors AS d ON d.doctor_id = a.doctor_id
JOIN services AS s ON s.service_id = a.service_id
JOIN specialties AS sp ON sp.specialty_id = s.specialty_id
WHERE a.starts_at >= TIMESTAMPTZ '2026-10-01 00:00:00+03'
  AND a.starts_at < TIMESTAMPTZ '2026-11-01 00:00:00+03'
ORDER BY a.starts_at, a.appointment_id;

-- 2.1.2. Врачи без единой записи за всю историю, включая отменённые.
-- Три таблицы; NULL появляется после LEFT JOIN, а не хранится в appointments.
SELECT d.doctor_id, d.full_name AS doctor, sp.name AS specialty,
       a.appointment_id
FROM doctors AS d
JOIN specialties AS sp ON sp.specialty_id = d.specialty_id
LEFT JOIN appointments AS a ON a.doctor_id = d.doctor_id
WHERE a.appointment_id IS NULL
ORDER BY d.doctor_id;

-- 2.1.3. Пациенты с запланированным платным приёмом невролога в ноябре.
-- DISTINCT убирает повтор пациента, если подходящих записей несколько.
SELECT DISTINCT p.patient_id, p.medical_record_number, p.full_name
FROM patients AS p
JOIN appointments AS a ON a.patient_id = p.patient_id
JOIN services AS s ON s.service_id = a.service_id
JOIN specialties AS sp ON sp.specialty_id = s.specialty_id
WHERE a.status = 'scheduled'
  AND a.charged_price > 0
  AND sp.name = 'Неврология'
  AND a.starts_at >= TIMESTAMPTZ '2026-11-01 00:00:00+03'
  AND a.starts_at < TIMESTAMPTZ '2026-12-01 00:00:00+03'
ORDER BY p.patient_id;
