-- Демо SQL-диалекта «Tarantool» (Settings → Languages & Frameworks →
-- SQL Dialects). Автосозданные источники получают его сразу; для этого
-- файла назначьте диалект вручную или откройте его в SQL-консоли
-- источника. Ложных ошибок подсветки нет даже на конструкциях,
-- которых нет в SQL-92.

-- Полный скан без индекса разрешает ключевое слово SEQSCAN:
SELECT * FROM SEQSCAN "users";

-- Или сессионная настройка (список имён подсказывает диалект):
SET SESSION "sql_seq_scan" = true;

-- Имена спейсов, созданных из Lua, — в нижнем регистре, поэтому
-- в кавычках; LIMIT/OFFSET — расширение диалекта:
SELECT "name", "email"
FROM SEQSCAN "users"
WHERE "city" = 'Москва'
LIMIT 10 OFFSET 0;

-- Джойн спейсов, агрегация:
SELECT u."name", COUNT(*) AS orders_count, SUM(o."total_amount") AS total
FROM SEQSCAN "orders" o
         JOIN "users" u ON u."id" = o."user_id"
GROUP BY u."name";

-- Типы данных Tarantool в DDL (UNSIGNED, STRING, UUID, DATETIME,
-- VARBINARY, SCALAR, MAP, ARRAY, ANY) — тоже часть диалекта:
CREATE TABLE IF NOT EXISTS audit_log
(
    id         UNSIGNED PRIMARY KEY AUTOINCREMENT,
    actor      STRING NOT NULL,
    payload    MAP,
    created_at DATETIME
);

-- Запись работает из грида и из консоли; каждая операция применяется
-- сервером сразу (эмуляция автокоммита в драйвере-обёртке):
INSERT INTO "users" ("id", "name", "email", "city")
VALUES (100, 'Тестовый Пользователь', 'test@example.com', 'Казань');

UPDATE "users" SET "city" = 'Новосибирск' WHERE "id" = 100;

DELETE FROM "users" WHERE "id" = 100;
