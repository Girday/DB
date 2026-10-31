BEGIN;

CREATE TABLE hospitals (
    hospital_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name text NOT NULL,
    address text NOT NULL
);

CREATE TABLE employment_books (
    employment_book_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    doctor_id bigint NOT NULL UNIQUE,

    CONSTRAINT employment_books_doctor_id_foreign_key
        FOREIGN KEY (doctor_id)
        REFERENCES doctors (doctor_id)
        ON DELETE RESTRICT
);

CREATE TABLE employment_records (
    employment_record_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employment_book_id bigint NOT NULL,
    hospital_id bigint NOT NULL,
    job_title text NOT NULL,
    salary numeric(12,2),
    hired_on date,
    dismissed_on date,

    CONSTRAINT employment_records_salary_nonnegative
        CHECK (salary >= 0),

    CONSTRAINT employment_records_dates_valid
        CHECK (dismissed_on IS NULL OR (hired_on IS NOT NULL AND dismissed_on >= hired_on)),

    CONSTRAINT employment_records_book_id_foreign_key
        FOREIGN KEY (employment_book_id)
        REFERENCES employment_books (employment_book_id)
        ON DELETE RESTRICT,

    CONSTRAINT employment_records_hospital_id_foreign_key
        FOREIGN KEY (hospital_id)
        REFERENCES hospitals (hospital_id)
        ON DELETE RESTRICT
);


INSERT INTO hospitals (name, address)
VALUES ('Исходная поликлиника', 'Адрес не указан');

INSERT INTO employment_books (doctor_id)
SELECT doctor_id
FROM doctors;

INSERT INTO employment_records (employment_book_id, hospital_id, job_title)
SELECT employment_books.employment_book_id, hospitals.hospital_id, 'Врач'
FROM employment_books
CROSS JOIN hospitals;

ALTER TABLE appointments
    ADD COLUMN employment_record_id bigint;

UPDATE appointments
SET employment_record_id = employment_records.employment_record_id
FROM employment_records
JOIN employment_books
    ON employment_books.employment_book_id = employment_records.employment_book_id
WHERE employment_books.doctor_id = appointments.doctor_id;

ALTER TABLE appointments
    ALTER COLUMN employment_record_id SET NOT NULL;

ALTER TABLE appointments
    ADD CONSTRAINT appointments_employment_record_id_foreign_key
        FOREIGN KEY (employment_record_id)
        REFERENCES employment_records (employment_record_id)
        ON DELETE RESTRICT;

DROP TRIGGER appointments_check_specialties ON appointments;
DROP FUNCTION check_appointment_specialties();

DROP TRIGGER doctors_prevent_used_specialty_change ON doctors;
DROP FUNCTION prevent_used_doctor_specialty_change();

ALTER TABLE appointments
    DROP COLUMN doctor_id;

COMMIT;
