# ER-диаграмма лабораторной работы №1

Вариант 7 — медицинская информационная система поликлиники.


```mermaid
erDiagram
    patients {
        bigint patient_id PK
        text medical_record_number UK
        text full_name
        date birth_date
    }

    specialties {
        bigint specialty_id PK
        text name UK
    }

    doctors {
        bigint doctor_id PK
        bigint specialty_id FK
        text full_name
    }

    services {
        bigint service_id PK
        bigint specialty_id FK
        text name
        numeric(10,2) price
    }

    appointments {
        bigint appointment_id PK
        bigint patient_id FK
        bigint doctor_id FK
        bigint service_id FK
        timestamptz starts_at
        text status
        numeric(10,2) charged_price
    }

    specialties ||..o{ doctors : ""
    specialties ||..o{ services : ""
    patients ||..o{ appointments : ""
    doctors ||..o{ appointments : ""
    services ||..o{ appointments : ""
```

## Типы данных

| Тип | Для чего используется |
|---|---|
| `bigint` | Целочисленные идентификаторы и ссылки на них |
| `text` | Номер карты, ФИО, названия и статус |
| `date` | Дата рождения без времени суток |
| `numeric(10,2)` | Точные денежные значения: до восьми цифр до десятичной точки и две после |
| `timestamptz` | Момент начала приёма |
