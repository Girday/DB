## Запуск PostgreSQL

Конфигурация: [compose.yaml](compose.yaml). Используется [официальный образ PostgreSQL](https://hub.docker.com/_/postgres) версии 17.11.

Параметры подключения с компьютера:

- адрес: `127.0.0.1`;
- порт: `5433`;
- база данных: `clinic_lab1`;
- пользователь: `lab1_user`;
- пароль: значение `POSTGRES_PASSWORD` в `.local/lab1_postgres.env`.

Файл `.local/lab1_postgres.env` исключён из Git. Для первоначального запуска в новом checkout его нужно создать с переменными `POSTGRES_USER=lab1_user`, `POSTGRES_DB=clinic_lab1` и `POSTGRES_PASSWORD` с выбранным паролем.

Структура базы и данные хранятся в томе Docker `db-lab1-pgdata`, отдельно от контейнера. При замене контейнера той же версией PostgreSQL и подключении прежнего тома база сохраняется. Обычная остановка контейнера также не удаляет базу. Часовая зона сервера — `Europe/Moscow`.

Команды выполняются из корня репозитория:

```sh
docker compose --project-name db-lab1 --file lab1/compose.yaml up --detach --wait
```

Для интерактивного подключения через клиент `psql` внутри контейнера:

```sh
docker exec -it db-lab1-postgres psql -U lab1_user -d clinic_lab1
```

В `psql` команда `\dt` показывает таблицы, `\q` завершает подключение.

Для первоначального создания структуры в пустой базе:

```sh
docker exec -i db-lab1-postgres psql -X -U lab1_user -d clinic_lab1 --set=ON_ERROR_STOP=1 --single-transaction --file=- < lab1/schema.sql
```

Для первоначального заполнения таблиц после создания структуры:

```sh
docker exec -i db-lab1-postgres psql -X -U lab1_user -d clinic_lab1 --set=ON_ERROR_STOP=1 --single-transaction --file=- < lab1/data.sql
```

## Запуск проверок ограничений

После заполнения базы:

```sh
docker exec -i db-lab1-postgres psql -X -U lab1_user -d clinic_lab1 --file=- < lab1/constraints_test.sql
```

| Код ошибки | Причина |
|---|---|
| `23502` | Нарушение `NOT NULL` |
| `23503` | Нарушение внешнего ключа, в том числе запрет удаления связанной строки |
| `23505` | Нарушение уникальности |
| `23514` | Нарушение `CHECK` или бизнес-правила с этим кодом в `RAISE EXCEPTION` |
