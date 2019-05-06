CREATE TABLE users (
    id    INTEGER PRIMARY KEY AUTOINCREMENT,
    name  TEXT NOT NULL
);

CREATE TABLE messages (
    id    INTEGER PRIMARY KEY AUTOINCREMENT,
    parent_id INTEGER NULL DEFAULT NULL REFERENCES messages ON DELETE SET NULL,
    sender_id INTEGER NOT NULL REFERENCES users ON DELETE RESTRICT,
    recipient_id INTEGER NULL DEFAULT NULL REFERENCES users ON DELETE RESTRICT,
    is_sent INTEGER NOT NULL DEFAULT 0 CHECK (is_sent IN (0,1)),
    is_read INTEGER NOT NULL DEFAULT 0 CHECK (is_read IN (0,1)),
    subject TEXT NOT NULL,
    message TEXT NOT NULL
);

--select incoming unread messages for specific user--
SELECT
    id,
    subject,
    message
FROM
    messages
WHERE
    recipient_id = 2
AND
    is_sent = 1
AND
    is_read = 0
ORDER BY id DESC;

--select incoming emails for specific user by 50 messages per page--
SELECT
    id,
    subject,
    message
FROM
    messages
WHERE
    recipient_id = 4
AND
    is_sent = 1
ORDER BY id DESC
LIMIT 50
OFFSET 0;

--select outgoing emails from specific user by 50 messages per page--
SELECT
    id,
    subject,
    message
FROM
    messages
WHERE
    sender_id = 3
AND
    is_sent = 1
ORDER BY id DESC
LIMIT 50
OFFSET 0;

--select user's drafts--
SELECT
    id,
    subject,
    message
FROM
    messages
WHERE
    sender_id = 3
AND
    is_sent = 0
ORDER BY id DESC