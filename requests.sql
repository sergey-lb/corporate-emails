CREATE TABLE users (
    id    INTEGER PRIMARY KEY AUTOINCREMENT,
    name  TEXT NOT NULL
);

ALTER TABLE users
ADD unit TEXT NULL;

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

--add trash and deletion (0 - not trashed, 1 - trashed, 2 - deleted)
ALTER TABLE
    messages
ADD
    sender_trash_level TEXT NOT NULL DEFAULT 'not_trashed' CHECK (sender_trash_level IN ('not_trashed','trashed','deleted'));

ALTER TABLE
    messages
ADD
    recipient_trash_level TEXT NOT NULL DEFAULT 'not_trashed' CHECK (recipient_trash_level IN ('not_trashed','trashed','deleted'));

--select incoming unread messages for specific user
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
AND
    recipient_trash_level = 'not_trashed'
ORDER BY id DESC;

--select incoming emails for specific user by 50 messages per page
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
AND
    recipient_trash_level = 'not_trashed'
ORDER BY id DESC
LIMIT 50
OFFSET 0;

--select outgoing emails from specific user by 50 messages per page
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
AND
    sender_trash_level = 'not_trashed'
ORDER BY id DESC
LIMIT 50
OFFSET 0;

--select user's drafts
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
AND
    sender_trash_level = 'not_trashed'
ORDER BY id DESC;

--create a message and keep it as a draft
INSERT INTO
    messages (sender_id, recipient_id, subject, message)
VALUES (
    4, 5, 'Новый черновик', 'Маша -> Даша. Новый черновик'
);

--create message and send it
INSERT INTO
    messages (sender_id, recipient_id, is_sent, subject, message)
VALUES (
    4, 5, 1, 'Новое отправленное письмо', 'Маша -> Даша. Новое отправленное письмо'
);

--send draft message
UPDATE
    messages
SET
    is_sent = 1
WHERE
    id = 61;

--place all drafts into trash
UPDATE
    messages
SET
    sender_trash_level = 'trashed'
WHERE
    sender_id = 8
AND
    is_sent = 0;

--trash all incoming messages
UPDATE
    messages
SET
    recipient_trash_level= 'trashed'
WHERE
    recipient_id = 8
AND
    is_sent = 1;

--empty trash
BEGIN TRANSACTION;

UPDATE
    messages
SET
    sender_trash_level = 'deleted'
WHERE
    sender_trash_level = 'trashed'
AND
    sender_id = 8;

UPDATE
    messages
SET
    recipient_trash_level = 'deleted'
WHERE
    recipient_trash_level = 'trashed'
AND
    recipient_id = 8;

COMMIT;

--stat query
SELECT
    cnt,
    type
FROM (
        SELECT
               count(*) cnt,
               'incoming' type
        FROM
             messages
        WHERE
              recipient_id = 10
        AND
              is_sent = 1
        AND
              recipient_trash_level = 'not_trashed'

    UNION

        SELECT
               count(*) cnt,
               'unread' type
        FROM
             messages
        WHERE
              recipient_id = 10
        AND
              is_sent = 1
        AND
              recipient_trash_level = 'not_trashed'
        AND
              is_read = 0
    UNION

        SELECT
            count(*) cnt,
            'sent' type
        FROM
            messages
        WHERE
            sender_id = 10
        AND
            is_sent = 1
        AND
            sender_trash_level = 'not_trashed'

    UNION

        SELECT
            count(*) cnt,
            'draft' type
        FROM
            messages
        WHERE
            sender_id = 10
        AND
            is_sent = 0
        AND
            sender_trash_level = 'not_trashed'
);

--Who is writing to whom
SELECT DISTINCT
    u1.name user1,
    u2.name user2
FROM
    messages m
INNER JOIN
    users u1
ON
    u1.id = m.sender_id
INNER JOIN
    users u2
ON
    u2.id = m.recipient_id
WHERE
    m.is_sent = 1
AND
    NOT EXISTS (
        SELECT
            id
        FROM
            messages m2
        WHERE
            m2.recipient_id = m.sender_id
        AND
            m2.sender_id = m.recipient_id
        AND
            m2.is_sent = 1
        AND
            m2.sender_id > m2.recipient_id
    );

--most active dialog
SELECT
    u1.name user1,
    u2.name user2,
    count(*) cnt
FROM (
    SELECT m.sender_id    user1_id,
           m.recipient_id user2_id
    FROM messages m
    WHERE m.is_sent = 1
      AND NOT EXISTS(
            SELECT id
            FROM messages m2
            WHERE m2.recipient_id = m.sender_id
              AND m2.sender_id = m.recipient_id
              AND m2.is_sent = 1
              AND m2.sender_id > m2.recipient_id

        )
    UNION ALL
    SELECT m.recipient_id    user1_id,
           m.sender_id user2_id
    FROM messages m
    WHERE m.is_sent = 1
      AND EXISTS(
            SELECT id
            FROM messages m2
            WHERE m2.recipient_id = m.sender_id
              AND m2.sender_id = m.recipient_id
              AND m2.is_sent = 1
              AND m2.sender_id > m2.recipient_id
        )
) tmp
INNER JOIN
    users u1
ON
    u1.id = tmp.user1_id
INNER JOIN
    users u2
ON
    u2.id = tmp.user2_id
GROUP BY user1, user2
ORDER BY cnt DESC
LIMIT 1;

--who is ignoring whom
SELECT DISTINCT
    u2.name user2,
    u1.name user1
FROM
    messages m
INNER JOIN
    users u1
ON
    u1.id = m.sender_id
INNER JOIN
    users u2
ON
    u2.id = m.recipient_id
WHERE
    m.is_sent = 1
AND NOT EXISTS(
    SELECT id
    FROM messages m2
    WHERE m2.sender_id = m.recipient_id
    AND m2.recipient_id = m.sender_id
    AND m2.is_sent = 1
);

--Who is writing to whom (units)
WITH units_msgs AS (
    SELECT
        m.id AS id,
        u1.unit AS sender_unit,
        u2.unit AS recipient_unit,
        m.is_sent AS is_sent
    FROM
        messages m
    INNER JOIN
        users u1
    ON
        u1.id = m.sender_id
    INNER JOIN
        users u2
    ON
        u2.id = m.recipient_id
)
SELECT DISTINCT
    sender_unit unit1,
    recipient_unit unit2
FROM
    units_msgs um
WHERE
    um.is_sent = 1
AND
    NOT EXISTS (
        SELECT
            id
        FROM
            units_msgs um2
        WHERE
            um2.recipient_unit = um.sender_unit
        AND
            um2.sender_unit = um.recipient_unit
        AND
            um2.is_sent = 1
        AND
            um2.sender_unit > um2.recipient_unit
    );

--most active dialogs (units)
WITH units_msgs AS (
    SELECT
        m.id AS id,
        u1.unit AS sender_unit,
        u2.unit AS recipient_unit,
        m.is_sent AS is_sent
    FROM
        messages m
    INNER JOIN
        users u1
    ON
        u1.id = m.sender_id
    INNER JOIN
        users u2
    ON
        u2.id = m.recipient_id
)
SELECT
    tmp.unit1,
    tmp.unit2,
    count(*) cnt
FROM (
    SELECT um.sender_unit    unit1,
           um.recipient_unit unit2
    FROM units_msgs um
    WHERE um.is_sent = 1
    AND NOT EXISTS(
        SELECT id
        FROM units_msgs um2
        WHERE um2.recipient_unit = um.sender_unit
            AND um2.sender_unit = um.recipient_unit
            AND um2.is_sent = 1
            AND um2.sender_unit > um2.recipient_unit
    )
    UNION ALL
    SELECT um.recipient_unit unit1,
           um.sender_unit unit2
    FROM units_msgs um
    WHERE um.is_sent = 1
      AND EXISTS(
            SELECT id
            FROM units_msgs um2
            WHERE um2.recipient_unit = um.sender_unit
              AND um2.sender_unit = um.recipient_unit
              AND um2.is_sent = 1
              AND um2.sender_unit > um2.recipient_unit
        )
) tmp
GROUP BY unit1, unit2
ORDER BY cnt DESC
LIMIT 1;

--who is ignoring whom (units)
WITH units_msgs AS (
    SELECT
        m.id AS id,
        u1.unit AS sender_unit,
        u2.unit AS recipient_unit,
        m.is_sent AS is_sent
    FROM
        messages m
    INNER JOIN
        users u1
    ON
        u1.id = m.sender_id
    INNER JOIN
        users u2
    ON
        u2.id = m.recipient_id
)
SELECT DISTINCT
    um.recipient_unit unit2,
    um.sender_unit unit1
FROM
    units_msgs um
WHERE
    um.is_sent = 1
AND NOT EXISTS(
    SELECT id
    FROM units_msgs um2
    WHERE um2.sender_unit = um.recipient_unit
    AND um2.recipient_unit = um.sender_unit
    AND um2.is_sent = 1
);

--retrieve message chain
WITH RECURSIVE msg_chain (id, parent_id, subject, message) AS (
    SELECT id, parent_id, subject, message
    FROM messages m
    WHERE
    id = 88
    UNION ALL
    SELECT m.id, m.parent_id, m.subject, m.message
    FROM messages m
    JOIN msg_chain mc
    ON m.id = mc.parent_id
)
SELECT * FROM msg_chain;

--find longest chain
WITH RECURSIVE msg_chain (id, parent_id, subject, message, first_message_id) AS (
    SELECT id, parent_id, subject, message, id
    FROM messages m
    UNION ALL
    SELECT m.id, m.parent_id, m.subject, m.message, mc.first_message_id
    FROM messages m
    JOIN msg_chain mc
    ON m.id = mc.parent_id
)
SELECT
    COUNT(*) chanin_length,
    first_message_id
FROM msg_chain
GROUP BY first_message_id
ORDER BY chanin_length DESC LIMIT 1;