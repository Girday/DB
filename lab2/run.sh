#!/bin/sh
set -eu

cd "$(dirname "$0")"

case "${1:-queries}" in
    queries) set -- 03_joins.sql 04_aggregates.sql 05_subqueries.sql 06_report.sql ;;
    data) set -- 01_data.sql ;;
    dml) set -- 02_dml.sql ;;
    checks) set -- 07_checks.sql ;;
    joins) set -- 03_joins.sql ;;
    aggregates) set -- 04_aggregates.sql ;;
    subqueries) set -- 05_subqueries.sql ;;
    report) set -- 06_report.sql ;;
    *) printf '%s\n' 'Использование: sh run.sh [queries|data|dml|checks|joins|aggregates|subqueries|report]'; exit 1 ;;
esac

docker compose --project-name db-lab1 --file ../lab1/compose.yaml up --detach --wait

for file in "$@"; do
    printf '\n%s\n' "$file"
    docker exec -i db-lab1-postgres psql -X -U lab1_user -d clinic_lab1 \
        --set=ON_ERROR_STOP=1 --file=- < "$file"
done
