-- 4. Отчёт по специальностям за сентябрь-ноябрь: количества, стоимость, отмены.
WITH source_data AS (
    -- Одна строка на приём за период со специальностью услуги.
    SELECT a.appointment_id, s.specialty_id, a.status, a.charged_price
    FROM appointments AS a
    JOIN services AS s ON s.service_id = a.service_id
    WHERE a.starts_at >= TIMESTAMPTZ '2026-09-01 00:00:00+03'
      AND a.starts_at < TIMESTAMPTZ '2026-12-01 00:00:00+03'
), totals AS (
    -- Только специальности с записями: COUNT(*) здесь всегда больше нуля.
    SELECT specialty_id, COUNT(*) AS appointment_count
    FROM source_data
    GROUP BY specialty_id
), completed AS (
    SELECT specialty_id, COUNT(*) AS completed_count,
           SUM(charged_price) AS completed_amount,
           ROUND(AVG(charged_price), 2) AS average_completed_price
    FROM source_data
    WHERE status = 'completed'
    GROUP BY specialty_id
), cancelled AS (
    SELECT specialty_id, COUNT(*) AS cancelled_count
    FROM source_data
    WHERE status = 'cancelled'
    GROUP BY specialty_id
), scheduled AS (
    SELECT specialty_id, COUNT(*) AS scheduled_count
    FROM source_data
    WHERE status = 'scheduled'
    GROUP BY specialty_id
), cancellation_rates AS (
    -- Знаменатель положителен, поскольку totals получен группировкой приёмов.
    SELECT t.specialty_id,
           ROUND(100.0 * COALESCE(c.cancelled_count, 0) / t.appointment_count, 2)
               AS cancellation_percent
    FROM totals AS t
    LEFT JOIN cancelled AS c ON c.specialty_id = t.specialty_id
)
-- Специальности без записей сохраняются; неопределённые среднее и доля остаются NULL.
SELECT sp.specialty_id, sp.name AS specialty,
       COALESCE(t.appointment_count, 0) AS appointment_count,
       COALESCE(c.completed_count, 0) AS completed_count,
       COALESCE(x.cancelled_count, 0) AS cancelled_count,
       COALESCE(s.scheduled_count, 0) AS scheduled_count,
       COALESCE(c.completed_amount, 0) AS completed_amount,
       c.average_completed_price,
       r.cancellation_percent
FROM specialties AS sp
LEFT JOIN totals AS t ON t.specialty_id = sp.specialty_id
LEFT JOIN completed AS c ON c.specialty_id = sp.specialty_id
LEFT JOIN cancelled AS x ON x.specialty_id = sp.specialty_id
LEFT JOIN scheduled AS s ON s.specialty_id = sp.specialty_id
LEFT JOIN cancellation_rates AS r ON r.specialty_id = sp.specialty_id
ORDER BY completed_amount DESC, sp.specialty_id;
