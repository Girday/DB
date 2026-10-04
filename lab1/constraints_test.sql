\set ON_ERROR_STOP off
\set VERBOSITY verbose

\echo '01. Повтор номера медицинской карты; ожидается 23505'
BEGIN;
INSERT INTO patients (medical_record_number, full_name, birth_date)
VALUES ('МК-000123', 'Тестовый пациент', '2000-01-01');
ROLLBACK;

\echo '02. NULL вместо обязательной даты рождения; ожидается 23502'
BEGIN;
INSERT INTO patients (medical_record_number, full_name, birth_date)
VALUES ('TEST-NULL-DATE', 'Тестовый пациент', NULL);
ROLLBACK;

\echo '03. Номер карты из одних пробелов; ожидается 23514'
BEGIN;
INSERT INTO patients (medical_record_number, full_name, birth_date)
VALUES ('   ', 'Тестовый пациент', '2000-01-01');
ROLLBACK;

\echo '04. Повтор названия специальности; ожидается 23505'
BEGIN;
INSERT INTO specialties (name) VALUES ('Терапия');
ROLLBACK;

\echo '05. Несуществующая специальность врача; ожидается 23503'
BEGIN;
INSERT INTO doctors (specialty_id, full_name)
VALUES (-999, 'Тестовый врач');
ROLLBACK;

\echo '06. Несуществующая специальность услуги; ожидается 23503'
BEGIN;
INSERT INTO services (specialty_id, name, price)
VALUES (-999, 'Тестовая услуга', 0);
ROLLBACK;

\echo '07. Отрицательная текущая цена услуги; ожидается 23514'
BEGIN;
INSERT INTO services (specialty_id, name, price)
VALUES (1, 'Тест отрицательной цены', -200);
ROLLBACK;

\echo '08. NULL вместо цены услуги; ожидается 23502'
BEGIN;
INSERT INTO services (specialty_id, name, price)
VALUES (1, 'Тест неизвестной цены', NULL);
ROLLBACK;

\echo '09. Повтор пары специальность/название при другой цене; ожидается 23505'
BEGIN;
INSERT INTO services (specialty_id, name, price)
VALUES (1, 'Первичный приём', 500);
ROLLBACK;

\echo '10. Недопустимый статус записи; ожидается 23514'
BEGIN;
UPDATE appointments SET status = 'scheduld' WHERE appointment_id = 1;
ROLLBACK;

\echo '11. Отрицательная согласованная цена записи; ожидается 23514'
BEGIN;
UPDATE appointments SET charged_price = -200 WHERE appointment_id = 1;
ROLLBACK;

\echo '12. Несуществующий пациент в записи; ожидается 23503'
BEGIN;
UPDATE appointments SET patient_id = -999 WHERE appointment_id = 1;
ROLLBACK;

\echo '13. Несуществующий врач в записи; ожидается 23503'
BEGIN;
UPDATE appointments SET doctor_id = -999 WHERE appointment_id = 1;
ROLLBACK;

\echo '14. Несуществующая услуга в записи; ожидается 23503'
BEGIN;
UPDATE appointments SET service_id = -999 WHERE appointment_id = 1;
ROLLBACK;

\echo '15. Вставка записи с разными специальностями врача и услуги; ожидается 23514'
BEGIN;
INSERT INTO appointments (patient_id, doctor_id, service_id, starts_at, charged_price)
VALUES (1, 3, 1, '2026-10-09 11:00:00+03', 0);
ROLLBACK;

\echo '16. Замена врача на врача другой специальности; ожидается 23514'
BEGIN;
UPDATE appointments SET doctor_id = 3 WHERE appointment_id = 1;
ROLLBACK;

\echo '17. Замена услуги на услугу другой специальности; ожидается 23514'
BEGIN;
UPDATE appointments SET service_id = 3 WHERE appointment_id = 1;
ROLLBACK;

\echo '18. Смена специальности врача с записями; ожидается 23514'
BEGIN;
UPDATE doctors SET specialty_id = 2 WHERE doctor_id = 1;
ROLLBACK;

\echo '19. Смена специальности услуги с записями; ожидается 23514'
BEGIN;
UPDATE services SET specialty_id = 1 WHERE service_id = 4;
ROLLBACK;

\echo '20. Две неотменённые записи одного врача в одно время; ожидается 23505'
BEGIN;
INSERT INTO appointments (patient_id, doctor_id, service_id, starts_at, charged_price)
VALUES (4, 1, 1, '2026-10-05 10:00:00+03', 0);
ROLLBACK;

\echo '21. Восстановление отменённой записи при уже занятом времени; ожидается 23505'
BEGIN;
UPDATE appointments SET status = 'scheduled' WHERE appointment_id = 3;
ROLLBACK;

\echo '22. Удаление пациента, на которого есть записи; ожидается 23503'
BEGIN;
DELETE FROM patients WHERE patient_id = 1;
ROLLBACK;

\echo '23. Удаление врача, на которого есть записи; ожидается 23503'
BEGIN;
DELETE FROM doctors WHERE doctor_id = 2;
ROLLBACK;

\echo '24. Удаление услуги, на которую есть записи; ожидается 23503'
BEGIN;
DELETE FROM services WHERE service_id = 4;
ROLLBACK;

\echo '25. Удаление специальности, используемой врачами; ожидается 23503'
BEGIN;
DELETE FROM specialties WHERE specialty_id = 1;
ROLLBACK;

\echo '26. Удаление специальности, используемой услугами; ожидается 23503'
BEGIN;
-- У врача №4 нет записей; его временное удаление допустимо.
DELETE FROM doctors WHERE doctor_id = 4;
-- Услуги №5 и №6 всё ещё ссылаются на специальность №3.
DELETE FROM specialties WHERE specialty_id = 3;
ROLLBACK;

\set ON_ERROR_STOP on
