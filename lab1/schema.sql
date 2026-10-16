CREATE TABLE patients (
    patient_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    medical_record_number text NOT NULL UNIQUE,
    full_name text NOT NULL,
    birth_date date NOT NULL,

    CONSTRAINT patients_medical_record_number_not_blank
        CHECK (btrim(medical_record_number) <> '')
);

CREATE TABLE specialties (
    specialty_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name text NOT NULL UNIQUE
);

CREATE TABLE doctors (
    doctor_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    specialty_id bigint NOT NULL,
    full_name text NOT NULL,

    CONSTRAINT doctors_specialty_id_fkey
        FOREIGN KEY (specialty_id)
        REFERENCES specialties (specialty_id)
        ON DELETE RESTRICT
);

CREATE TABLE services (
    service_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    specialty_id bigint NOT NULL,
    name text NOT NULL,
    price numeric(10,2) NOT NULL,

    CONSTRAINT services_price_nonnegative
        CHECK (price >= 0),
    CONSTRAINT services_specialty_name_key
        UNIQUE (specialty_id, name),
    CONSTRAINT services_specialty_id_fkey
        FOREIGN KEY (specialty_id)
        REFERENCES specialties (specialty_id)
        ON DELETE RESTRICT
);

CREATE TABLE appointments (
    appointment_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    patient_id bigint NOT NULL,
    doctor_id bigint NOT NULL,
    service_id bigint NOT NULL,
    starts_at timestamptz NOT NULL,
    status text NOT NULL DEFAULT 'scheduled',
    charged_price numeric(10,2) NOT NULL,

    CONSTRAINT appointments_charged_price_nonnegative
        CHECK (charged_price >= 0),
    CONSTRAINT appointments_status_valid
        CHECK (status IN ('scheduled', 'completed', 'cancelled')),
    CONSTRAINT appointments_patient_id_fkey
        FOREIGN KEY (patient_id)
        REFERENCES patients (patient_id)
        ON DELETE RESTRICT,
    CONSTRAINT appointments_doctor_id_fkey
        FOREIGN KEY (doctor_id)
        REFERENCES doctors (doctor_id)
        ON DELETE RESTRICT,
    CONSTRAINT appointments_service_id_fkey
        FOREIGN KEY (service_id)
        REFERENCES services (service_id)
        ON DELETE RESTRICT
);


CREATE FUNCTION check_appointment_specialties()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    doctor_specialty bigint;
    service_specialty bigint;
BEGIN
    SELECT specialty_id
    INTO doctor_specialty
    FROM doctors
    WHERE doctor_id = NEW.doctor_id
    FOR SHARE;

    SELECT specialty_id
    INTO service_specialty
    FROM services
    WHERE service_id = NEW.service_id
    FOR SHARE;

    -- Если связанной строки нет, её отсутствие проверит внешний ключ.
    IF doctor_specialty <> service_specialty THEN
        RAISE EXCEPTION 'Специальности врача и услуги должны совпадать'
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER appointments_check_specialties
BEFORE INSERT OR UPDATE OF doctor_id, service_id
ON appointments
FOR EACH ROW
EXECUTE FUNCTION check_appointment_specialties();


CREATE FUNCTION prevent_used_doctor_specialty_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.specialty_id <> OLD.specialty_id
       AND EXISTS (
           SELECT 1
           FROM appointments
           WHERE doctor_id = OLD.doctor_id
       ) THEN
        RAISE EXCEPTION 'Нельзя менять специальность врача, у которого есть записи на приём'
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER doctors_prevent_used_specialty_change
BEFORE UPDATE OF specialty_id
ON doctors
FOR EACH ROW
EXECUTE FUNCTION prevent_used_doctor_specialty_change();


CREATE FUNCTION prevent_used_service_specialty_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.specialty_id <> OLD.specialty_id
       AND EXISTS (
           SELECT 1
           FROM appointments
           WHERE service_id = OLD.service_id
       ) THEN
        RAISE EXCEPTION 'Нельзя менять специальность услуги, на которую есть записи на приём'
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER services_prevent_used_specialty_change
BEFORE UPDATE OF specialty_id
ON services
FOR EACH ROW
EXECUTE FUNCTION prevent_used_service_specialty_change();


CREATE UNIQUE INDEX appointments_doctor_start_not_cancelled_key
ON appointments (doctor_id, starts_at)
WHERE status <> 'cancelled';
