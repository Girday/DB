-- Однократное заполнение пустой учебной базы. Все имена, даты и тарифы условные.
-- Сначала добавляем строки, на которые будут ссылаться врачи и записи.
INSERT INTO specialties (name)
VALUES
    ('Терапия'),
    ('Офтальмология'),
    ('Неврология')
RETURNING specialty_id, name;

-- Два разных пациента намеренно имеют одинаковые ФИО и дату рождения.
-- Разные форматы номеров карт демонстрируют согласованное правило.
INSERT INTO patients (medical_record_number, full_name, birth_date)
VALUES
    ('МК-000123', 'Анна Сергеевна Иванова', '1998-04-12'),
    ('000124', 'Анна Сергеевна Иванова', '1998-04-12'),
    ('КАРТА-125', 'Максим Александрович Смирнов', '1985-11-20'),
    ('МК-000126', 'Ольга Андреевна Соколова', '2002-07-03')
RETURNING patient_id, medical_record_number, full_name, birth_date;

-- Специальности уже существуют: 1 — терапия, 2 — офтальмология, 3 — неврология.
-- Два врача одной специальности допустимы.
INSERT INTO doctors (specialty_id, full_name)
VALUES
    (1, 'Елена Викторовна Петрова'),
    (1, 'Алексей Игоревич Кузнецов'),
    (2, 'Мария Андреевна Соколова'),
    (3, 'Дмитрий Павлович Орлов')
RETURNING doctor_id, specialty_id, full_name;

-- Название услуги может повторяться в разных специальностях.
-- Бесплатная услуга имеет цену 0; положительная цена — условный учебный тариф.
INSERT INTO services (specialty_id, name, price)
VALUES
    (1, 'Первичный приём', 0.00),
    (1, 'Повторный приём', 0.00),
    (2, 'Первичный приём', 0.00),
    (2, 'Расширенное обследование зрения', 1000.00),
    (3, 'Первичный приём', 0.00),
    (3, 'Повторный приём', 0.00)
RETURNING service_id, specialty_id, name, price;

-- Бесплатный первичный приём; status получит DEFAULT scheduled.
INSERT INTO appointments (patient_id, doctor_id, service_id, starts_at, charged_price)
SELECT 1, 1, service_id, '2026-10-05 10:00:00+03', price
FROM services
WHERE service_id = 1
RETURNING appointment_id, patient_id, doctor_id, service_id, starts_at, status, charged_price;

-- Повторная запись того же пациента, без повторного добавления patients.
INSERT INTO appointments (patient_id, doctor_id, service_id, starts_at, charged_price)
SELECT 1, 1, service_id, '2026-10-12 10:00:00+03', price
FROM services
WHERE service_id = 2
RETURNING appointment_id, patient_id, doctor_id, service_id, starts_at, status, charged_price;

-- Отменённая запись сохраняется в истории.
INSERT INTO appointments (patient_id, doctor_id, service_id, starts_at, charged_price, status)
SELECT 2, 1, service_id, '2026-10-05 10:30:00+03', price, 'cancelled'
FROM services
WHERE service_id = 1
RETURNING appointment_id, patient_id, doctor_id, service_id, starts_at, status, charged_price;

-- После отмены время того же врача можно занять новой записью.
INSERT INTO appointments (patient_id, doctor_id, service_id, starts_at, charged_price)
SELECT 3, 1, service_id, '2026-10-05 10:30:00+03', price
FROM services
WHERE service_id = 1
RETURNING appointment_id, patient_id, doctor_id, service_id, starts_at, status, charged_price;

-- Завершённый приём сохраняет прежний тариф 1000.00.
INSERT INTO appointments (patient_id, doctor_id, service_id, starts_at, charged_price, status)
SELECT 3, 3, service_id, '2026-10-01 09:00:00+03', price, 'completed'
FROM services
WHERE service_id = 4
RETURNING appointment_id, patient_id, doctor_id, service_id, starts_at, status, charged_price;

-- Будущий приём также согласован по старому тарифу 1000.00.
INSERT INTO appointments (patient_id, doctor_id, service_id, starts_at, charged_price)
SELECT 4, 3, service_id, '2026-10-07 09:30:00+03', price
FROM services
WHERE service_id = 4
RETURNING appointment_id, patient_id, doctor_id, service_id, starts_at, status, charged_price;

-- Другой врач может принимать в тот же момент.
INSERT INTO appointments (patient_id, doctor_id, service_id, starts_at, charged_price)
SELECT 4, 2, service_id, '2026-10-05 10:00:00+03', price
FROM services
WHERE service_id = 1
RETURNING appointment_id, patient_id, doctor_id, service_id, starts_at, status, charged_price;

-- Изменение текущего тарифа не переписывает charged_price существующих записей.
UPDATE services
SET price = 1500.00
WHERE service_id = 4
RETURNING service_id, name, price;

-- Новая запись получает новый тариф 1500.00.
INSERT INTO appointments (patient_id, doctor_id, service_id, starts_at, charged_price)
SELECT 1, 3, service_id, '2026-10-08 10:00:00+03', price
FROM services
WHERE service_id = 4
RETURNING appointment_id, patient_id, doctor_id, service_id, starts_at, status, charged_price;
