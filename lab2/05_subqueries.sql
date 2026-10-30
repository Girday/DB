-- 3.1. Услуги дороже среднего текущего тарифа своей специальности.
-- Среднее включает бесплатные услуги и саму сравниваемую услугу.
SELECT s.service_id, sp.name AS specialty, s.name AS service, s.price
FROM services AS s
JOIN specialties AS sp ON sp.specialty_id = s.specialty_id
WHERE s.price > (
    SELECT AVG(other.price)
    FROM services AS other
    WHERE other.specialty_id = s.specialty_id
)
ORDER BY sp.name, s.price DESC, s.service_id;

-- 3.2. Пациенты, которым оказали хотя бы одну платную услугу.
-- EXISTS не размножает пациента при нескольких подходящих приёмах.
SELECT p.patient_id, p.medical_record_number, p.full_name
FROM patients AS p
WHERE EXISTS (
    SELECT 1
    FROM appointments AS a
    WHERE a.patient_id = p.patient_id
      AND a.status = 'completed'
      AND a.charged_price > 0
)
ORDER BY p.patient_id;

-- 3.3. Пациенты с отменами, но без единого завершённого приёма.
-- Список для оператора: проверить, нужна ли пациенту повторная запись.
-- Пациенты без записей вообще сюда не попадают благодаря первому EXISTS.
SELECT p.patient_id, p.medical_record_number, p.full_name
FROM patients AS p
WHERE EXISTS (
    SELECT 1
    FROM appointments AS cancelled
    WHERE cancelled.patient_id = p.patient_id
      AND cancelled.status = 'cancelled'
)
  AND NOT EXISTS (
    SELECT 1
    FROM appointments AS completed
    WHERE completed.patient_id = p.patient_id
      AND completed.status = 'completed'
)
ORDER BY p.patient_id;

-- 3.4. Дата последнего завершённого приёма для каждого пациента.
-- Подзапрос вычисляет индивидуальный показатель по p.patient_id.
-- MAX по пустому набору возвращает NULL: завершённых приёмов не было.
SELECT p.patient_id, p.medical_record_number, p.full_name,
       (
           SELECT MAX(a.starts_at)
           FROM appointments AS a
           WHERE a.patient_id = p.patient_id
             AND a.status = 'completed'
       ) AS last_completed_at
FROM patients AS p
ORDER BY p.patient_id;
