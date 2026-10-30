-- 1.2. Демонстрация изменений. Запускать отдельно от других транзакций.
-- Все изменения строк в этом сценарии отменяются в конце.
BEGIN;

-- 1. Новый пациент и две связанные записи; идентификаторы находим по ключам.
INSERT INTO patients (medical_record_number, full_name, birth_date)
VALUES ('ЛР2-DEMO', 'Виктор Сергеевич Демин', DATE '1990-01-10')
RETURNING patient_id, medical_record_number;

INSERT INTO appointments (patient_id, doctor_id, service_id, starts_at, status, charged_price)
SELECT p.patient_id, d.doctor_id, s.service_id, dates.starts_at, 'scheduled', s.price
FROM patients AS p
CROSS JOIN (VALUES
    (TIMESTAMPTZ '2026-12-01 09:00:00+03'),
    (TIMESTAMPTZ '2026-12-02 09:00:00+03')
) AS dates(starts_at)
JOIN doctors AS d ON d.full_name = 'Роман Олегович Белов'
JOIN services AS s ON s.specialty_id = d.specialty_id
                  AND s.name = 'Расширенная консультация терапевта'
WHERE p.medical_record_number = 'ЛР2-DEMO'
RETURNING appointment_id, starts_at, status, charged_price;

-- 2. Первый приём состоялся: меняем состояние одной операции.
UPDATE appointments
SET status = 'completed'
WHERE patient_id = (
    SELECT patient_id FROM patients WHERE medical_record_number = 'ЛР2-DEMO'
)
  AND starts_at = TIMESTAMPTZ '2026-12-01 09:00:00+03'
  AND status = 'scheduled'
RETURNING appointment_id, status;

-- Тарифы до массового изменения.
SELECT s.name, s.price
FROM services AS s
JOIN specialties AS sp ON sp.specialty_id = s.specialty_id
WHERE sp.name = 'Терапия' AND s.price > 0
ORDER BY s.service_id;

-- 3. Платные услуги терапии дорожают на 10%; бесплатные остаются бесплатными.
-- charged_price в существующих записях сохраняет прежнюю согласованную цену.
UPDATE services
SET price = ROUND(price * 1.10, 2)
WHERE price > 0
  AND specialty_id = (SELECT specialty_id FROM specialties WHERE name = 'Терапия')
RETURNING service_id, name, price;

-- 4. Удаляем ошибочно созданную вторую запись, а не её пациента.
-- Родительского пациента пока нельзя удалить из-за ссылки из первого приёма.
DELETE FROM appointments
WHERE patient_id = (
    SELECT patient_id FROM patients WHERE medical_record_number = 'ЛР2-DEMO'
)
  AND starts_at = TIMESTAMPTZ '2026-12-02 09:00:00+03'
RETURNING appointment_id, starts_at;

SELECT a.starts_at, a.status, a.charged_price
FROM appointments AS a
JOIN patients AS p ON p.patient_id = a.patient_id
WHERE p.medical_record_number = 'ЛР2-DEMO';

-- 5. Отмена всей демонстрации: INSERT, UPDATE и DELETE.
ROLLBACK;

-- Пациента больше нет; тарифы вернулись к исходным значениям.
SELECT COUNT(*) AS demo_patients_after_rollback
FROM patients
WHERE medical_record_number = 'ЛР2-DEMO';

SELECT s.name, s.price
FROM services AS s
JOIN specialties AS sp ON sp.specialty_id = s.specialty_id
WHERE sp.name = 'Терапия' AND s.price > 0
ORDER BY s.service_id;

-- Значения последовательностей IDENTITY после ROLLBACK не возвращаются назад.
