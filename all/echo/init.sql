CREATE TABLE
    Users (
        id SERIAL PRIMARY KEY,
        user_id VARCHAR(20) NOT NULL UNIQUE,
        password VARCHAR(20)
    );

CREATE TABLE
    rooms (
        room_id SERIAL PRIMARY KEY,
        room_name VARCHAR(100) NOT NULL,
        location INT
    );

CREATE TABLE
    beacons (
        beacon_id SERIAL PRIMARY KEY,
        beacon_name VARCHAR(100) NOT NULL,
        service_uuid CHAR(36),
        mac_address VARCHAR(17),
        room_id INT,
        FOREIGN KEY (room_id) REFERENCES rooms (room_id)
    );

CREATE TABLE
    wifi_access_points (
        wifi_id SERIAL PRIMARY KEY,
        ssid VARCHAR(100) NOT NULL,
        bssid VARCHAR(17) NOT NULL,
        room_id INT,
        FOREIGN KEY (room_id) REFERENCES rooms (room_id)
    );

CREATE TABLE
    roles (
        role_id SERIAL PRIMARY KEY,
        role_name VARCHAR(50) NOT NULL
    );

CREATE TABLE
    user_roles (
        user_id INT,
        role_id INT,
        PRIMARY KEY (user_id, role_id),
        FOREIGN KEY (user_id) REFERENCES users (id),
        FOREIGN KEY (role_id) REFERENCES roles (role_id)
    );

CREATE TABLE
    query_server (
        id SERIAL PRIMARY KEY,
        url VARCHAR(255) NOT NULL
    );

-- ユーザーの在室セッションを保存するテーブル
CREATE TABLE
    user_presence_sessions (
        session_id SERIAL PRIMARY KEY,
        user_id INT REFERENCES Users (id),
        room_id INT REFERENCES rooms (room_id),
        start_time TIMESTAMP NOT NULL,
        end_time TIMESTAMP,
        last_seen TIMESTAMP NOT NULL
    );

-- インデックスの追加
CREATE INDEX idx_user_presence_sessions_user_id ON user_presence_sessions (user_id);

CREATE INDEX idx_user_presence_sessions_end_time ON user_presence_sessions (end_time);

CREATE INDEX idx_user_presence_sessions_last_seen ON user_presence_sessions (last_seen);

-- ユーザーのデータを挿入
INSERT INTO
    Users (user_id, password)
VALUES
    ('相川 拓哉', 'password1'),
    ('hihumikan', 'password2'),
    ('harutiro', 'password3');

-- 部屋のデータを挿入
INSERT INTO
    rooms (room_name, location)
VALUES
    ('Graduate Students Room', 513),
    ('Undergraduate Students Room', 514),
    ('Professors Office', 515);

-- ビーコンデバイスのデータを挿入
INSERT INTO
    beacons (
        beacon_name,
        service_uuid,
        mac_address,
        room_id
    )
VALUES
    (
        'elpis-001',
        'd546df97-4757-47ef-be09-3e2dcbdd0c77',
        'DC:0D:30:1E:33:91',
        2
    ),
    (
        'elpis-001',
        'fda50693-a4e2-4fb1-afcf-c6eb07647825',
        'DC:0D:30:1E:33:91',
        2
    ),
    (
        'elpis-002',
        '4e24ac47-b7e6-44f5-957f-1cdcefa2acab',
        'DC:0D:30:1E:33:84',
        1
    ),
    (
        'elpis-002',
        'fda50693-a4e2-4fb1-afcf-c6eb07647825',
        'DC:0D:30:1E:33:84',
        1
    ),
    (
        'elpis-003',
        '722eb21f-8f6a-4ba9-a12f-05c0f970a177',
        'DC:0D:30:1E:33:3E',
        3
    );

-- WiFiアクセスポイントのデータを挿入
INSERT INTO
    wifi_access_points (ssid, bssid, room_id)
VALUES
    ('KJLB-WorkRoom-g', 'C0:25:A2:A7:2E:1A', 1),
    ('KJLB-StuRoom-108ac', 'C0:25:A2:A9:b1:4f', 2),
    ('KJLB-StuRoom-108g', 'c0:25:a2:a7:2e:2a', 2),
    ('KJLB-104a', '60:84:bd:de:7c:67', 3),
    ('KJLB-104g', '60:84:bd:de:7c:60', 3);

-- ロールのデータを挿入
INSERT INTO
    roles (role_name)
VALUES
    ('Admin'),
    ('User'),
    ('Guest');

-- ユーザーロールのデータを挿入
INSERT INTO
    user_roles (user_id, role_id)
VALUES
    (1, 1),
    (2, 1),
    (3, 1);
