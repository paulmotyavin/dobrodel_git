CREATE TYPE user_role AS ENUM (
    'ВОЛОНТЕР',
    'ОРГАНИЗАТОР',
    'МОДЕРАТОР',
    'АДМИНИСТРАТОР'
);

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    surname VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NULL,
    phone VARCHAR(20) UNIQUE NOT NULL,
    birth_date DATE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role user_role NOT NULL DEFAULT 'ВОЛОНТЕР',
    avatar_url VARCHAR(255) NULL,
    points INTEGER NOT NULL DEFAULT 0 CHECK (points >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE tokens (
    id SERIAL PRIMARY KEY,
    token VARCHAR NOT NULL UNIQUE,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_revoked BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE organizations (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    contact_phone VARCHAR(20),
    contact_email VARCHAR(100) UNIQUE,
    documents TEXT[],
    verified BOOLEAN DEFAULT FALSE,
    created_by INTEGER REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT
);

-- Добавление новых категорий
INSERT INTO categories (name, description) VALUES
('Животные', 'Категория, связанная с животными'),
('Социальная помощь', 'Категория, связанная с социальной помощью'),
('Экология', 'Категория, связанная с экологией'),
('Образование', 'Категория, связанная с образованием'),
('Религия', 'Категория, связанная с религией');

CREATE TABLE tags (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL
);

-- Добавление различных тегов
INSERT INTO tags (name) VALUES
('Помощь'),
('Волонтерство'),
('Экологические проекты'),
('Образовательные программы'),
('Социальные инициативы'),
('Защита животных'),
('Культура'),
('Спорт'),
('Здоровье'),
('Творчество');

CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE locations (
    id SERIAL PRIMARY KEY,
    address TEXT NOT NULL,
    geom GEOMETRY(Point, 4326)
);

CREATE TYPE project_status AS ENUM (
    'В_ПРОЦЕССЕ',
    'ОЖИДАЕТСЯ',
    'ПРОШЕЛ',
    'ОТМЕНЕН'
);

CREATE TABLE projects (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    category_id INTEGER REFERENCES categories(id) ON DELETE CASCADE,
    location_id INTEGER REFERENCES locations(id) ON DELETE CASCADE,
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    status project_status NOT NULL,
    min_age INT NULL CHECK (min_age BETWEEN 14 AND 100 OR min_age IS NULL),
    organizer_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    organization_id INTEGER REFERENCES organizations(id) ON DELETE CASCADE,
    max_participants INTEGER NOT NULL DEFAULT 0 CHECK (max_participants > 0),
    image_url VARCHAR(250) NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CHECK (end_date > start_date)
);

CREATE TABLE project_reviews (
    id SERIAL PRIMARY KEY,
    project_id INTEGER NOT NULL REFERENCES projects(id),
    user_id INTEGER NOT NULL REFERENCES users(id),
    rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE project_tags (
    project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
    tag_id INTEGER REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (project_id, tag_id)
);

CREATE TABLE user_favorite_projects (
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, project_id)
);

CREATE TABLE user_favorite_categories (
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    category_id INTEGER REFERENCES categories(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, category_id)
);

CREATE TYPE registration_status AS ENUM (
    'ОЖИДАЕТСЯ',
    'ПОДТВЕРЖДЕН',
    'ОТМЕНЕН',
    'ПРОСРОЧЕН'
);

CREATE OR REPLACE FUNCTION generate_custom_code()
RETURNS VARCHAR AS $$
DECLARE
    generated_code  VARCHAR(12);
    allowed_chars TEXT := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    random_bytes BYTEA;
    i INT;
BEGIN
    LOOP
        random_bytes := gen_random_bytes(12);
        generated_code := '';

        FOR i IN 1..12 LOOP
            generated_code := generated_code || SUBSTRING(
                allowed_chars,
                (get_byte(random_bytes, i - 1) % LENGTH(allowed_chars)) + 1,
                1
            );
        END LOOP;

        IF NOT EXISTS (SELECT 1 FROM registrations WHERE code = generated_code) THEN
            RETURN generated_code;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE registrations (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    project_id INTEGER REFERENCES projects(id) ON DELETE CASCADE,
    registration_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    code VARCHAR(12) DEFAULT generate_custom_code(),
    status registration_status NOT NULL DEFAULT 'ОЖИДАЕТСЯ',
    confirmed_at TIMESTAMP WITH TIME ZONE,
    UNIQUE (user_id, project_id)
);

CREATE TYPE achievement_type AS ENUM (
    'КОЛИЧЕСТВО_ПРОЕКТОВ',
    'СУММА_БАЛЛОВ',
    'ПРОЕКТЫ_ПО_КАТЕГОРИЯМ',
    'КОМБИНИРОВАННЫЕ',
    'СЕРИЯ'
);

CREATE TABLE achievements (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT NOT NULL,
    image_url TEXT NOT NULL,
    type achievement_type NOT NULL,
    criteria JSONB NOT NULL
);

CREATE TABLE achievement_progress (
    user_id INTEGER REFERENCES users(id),
    achievement_id INTEGER REFERENCES achievements(id),
    current_count INTEGER NOT NULL DEFAULT 0,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, achievement_id)
);

CREATE TABLE user_achievements (
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    achievement_id INTEGER REFERENCES achievements(id) ON DELETE CASCADE,
    awarded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, achievement_id)
);

CREATE TABLE rewards (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT NOT NULL,
    image_url TEXT NOT NULL,
    required_points INTEGER NOT NULL CHECK (required_points > 0)
);

CREATE TABLE user_rewards (
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    reward_id INTEGER REFERENCES rewards(id) ON DELETE CASCADE,
    redeemed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, reward_id)
);

CREATE TYPE transaction_type AS ENUM (
    'РЕГИСТРАЦИЯ',
    'ПОСЕЩЕНИЕ',
    'НАГРАДА',
    'ДРУГОЕ'
);

CREATE TABLE point_transactions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount INTEGER NOT NULL,
    source_type transaction_type NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE tickets (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    is_open BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE ticket_messages (
    id SERIAL PRIMARY KEY,
    ticket_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (ticket_id) REFERENCES tickets(id) ON DELETE CASCADE
);

CREATE OR REPLACE FUNCTION update_user_points()
RETURNS TRIGGER AS $$
DECLARE
    delta INTEGER;
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.type = 'НАГРАДА' THEN
            delta := -NEW.amount;
        ELSE
            delta := NEW.amount;
        END IF;

        UPDATE users
        SET points = points + delta
        WHERE id = NEW.user_id;

    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.type = 'НАГРАДА' THEN
            delta := OLD.amount;
        ELSE
            delta := -OLD.amount;
        END IF;

        UPDATE users
        SET points = points + delta
        WHERE id = OLD.user_id;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_point_transactions_after
AFTER INSERT OR DELETE ON point_transactions
FOR EACH ROW EXECUTE FUNCTION update_user_points();

CREATE INDEX idx_locations_geom
  ON locations USING GIST(geom);

CREATE INDEX idx_projects_organizer ON projects(organizer_id);
CREATE INDEX idx_registrations_user ON registrations(user_id);
CREATE INDEX idx_transactions_user ON point_transactions(user_id);
CREATE INDEX idx_projects_category ON projects(category_id);
CREATE INDEX idx_projects_dates ON projects(start_date, end_date);

CREATE OR REPLACE FUNCTION set_registration_code()
RETURNS TRIGGER AS $$
BEGIN
    NEW.code := public.generate_custom_code();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_insert_registration
BEFORE INSERT ON registrations
FOR EACH ROW
EXECUTE FUNCTION set_registration_code();

CREATE OR REPLACE FUNCTION update_expired_registrations()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE registrations r
  SET status = 'ПРОСРОЧЕН'
  FROM projects p
  WHERE r.project_id = p.id
    AND p.end_date < CURRENT_TIMESTAMP
    AND r.status NOT IN ('ПОДТВЕРЖДЕН', 'ОТМЕНЕН');
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_project_expiry
AFTER INSERT OR UPDATE ON projects
FOR EACH ROW EXECUTE FUNCTION update_expired_registrations();

CREATE OR REPLACE FUNCTION create_welcome_points()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO point_transactions (
        user_id,
        amount,
        type,
        description,
        created_at
    ) VALUES (
        NEW.id,
        250,
        'РЕГИСТРАЦИЯ',
        'Бонус за регистрацию',
        CURRENT_TIMESTAMP
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_after_user_insert
AFTER INSERT ON users
FOR EACH ROW
EXECUTE FUNCTION create_welcome_points();

CREATE TABLE IF NOT EXISTS fsm_states (
    id SERIAL PRIMARY KEY,
    bot_id BIGINT NOT NULL,
    chat_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    state VARCHAR(255),
    CONSTRAINT fsm_state_unique UNIQUE (bot_id, chat_id, user_id)
);

CREATE TABLE IF NOT EXISTS fsm_data (
    id SERIAL PRIMARY KEY,
    bot_id BIGINT NOT NULL,
    chat_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    data JSONB,
    CONSTRAINT fsm_data_unique UNIQUE (bot_id, chat_id, user_id)
);
