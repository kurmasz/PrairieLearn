CREATE TABLE IF NOT EXISTS rubrics (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    starting_points DOUBLE PRECISION NOT NULL,
    max_points DOUBLE PRECISION NOT NULL,
    min_points DOUBLE PRECISION NOT NULL,
    modified_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS rubric_items (
    id BIGSERIAL PRIMARY KEY,
    rubric_id BIGINT NOT NULL REFERENCES rubrics(id) ON DELETE CASCADE ON UPDATE CASCADE,
    number BIGINT NOT NULL,
    points DOUBLE PRECISION NOT NULL,
    short_text TEXT,
    description TEXT,
    staff_instructions TEXT,
    key_binding TEXT,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS rubric_items_rubric_id ON rubric_items(rubric_id);

CREATE TABLE IF NOT EXISTS rubric_gradings (
    id BIGSERIAL PRIMARY KEY,
    rubric_id BIGINT NOT NULL REFERENCES rubrics(id) ON DELETE CASCADE ON UPDATE CASCADE,
    computed_points DOUBLE PRECISION NOT NULL,
    adjust_points DOUBLE PRECISION NOT NULL,
    deleted_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS rubric_grading_items (
    id BIGSERIAL PRIMARY KEY,
    rubric_grading_id BIGINT NOT NULL REFERENCES rubric_gradings(id) ON DELETE CASCADE ON UPDATE CASCADE,
    rubric_item_id BIGINT NOT NULL REFERENCES rubric_items(id) ON DELETE CASCADE ON UPDATE CASCADE,
    score DOUBLE PRECISION NOT NULL DEFAULT 1,
    points DOUBLE PRECISION NOT NULL,
    short_text TEXT,
    note TEXT,
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- TODO Consider other indices

ALTER TABLE rubric_grading_items DROP CONSTRAINT IF EXISTS rubric_grading_items_rubric_grading_id_rubric_item_id_key;
ALTER TABLE rubric_grading_items ADD CONSTRAINT rubric_grading_items_rubric_grading_id_rubric_item_id_key UNIQUE (rubric_grading_id, rubric_item_id);

ALTER TABLE assessment_questions ADD COLUMN IF NOT EXISTS manual_rubric_id BIGINT REFERENCES rubrics(id) ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE assessment_questions ADD COLUMN IF NOT EXISTS auto_rubric_id BIGINT REFERENCES rubrics(id) ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE instance_questions ADD COLUMN IF NOT EXISTS manual_rubric_grading_id BIGINT REFERENCES rubric_gradings(id) ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE instance_questions ADD COLUMN IF NOT EXISTS auto_rubric_grading_id BIGINT REFERENCES rubric_gradings(id) ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE grading_jobs ADD COLUMN IF NOT EXISTS manual_rubric_grading_id BIGINT REFERENCES rubric_gradings(id) ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE grading_jobs ADD COLUMN IF NOT EXISTS auto_rubric_grading_id BIGINT REFERENCES rubric_gradings(id) ON DELETE SET NULL ON UPDATE CASCADE;

