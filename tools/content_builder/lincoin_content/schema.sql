-- content.db: read-only learning content. See docs/03-database.md.
-- IDs are stable across versions; user progress refers to them.

CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);

CREATE TABLE sources (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  homepage TEXT NOT NULL,
  license TEXT NOT NULL CHECK (license <> ''),
  license_url TEXT NOT NULL CHECK (license_url <> ''),
  attribution TEXT NOT NULL CHECK (attribution <> ''),
  version TEXT,
  files_json TEXT NOT NULL      -- url, sha256, retrieved_at per file
);

CREATE TABLE words (
  id TEXT PRIMARY KEY,           -- 'w:<JMdict ent_seq>'
  jlpt_level INTEGER,            -- 5..1, unofficial estimate
  order_in_level INTEGER NOT NULL,
  pos TEXT NOT NULL,             -- JSON list of JMdict POS codes (first sense)
  tags TEXT NOT NULL,            -- JSON list (e.g. uk, common)
  is_common INTEGER NOT NULL,
  freq_rank INTEGER NOT NULL,    -- best JMdict nfXX bucket, 99 = none
  source_id TEXT NOT NULL REFERENCES sources(id),
  level_source_id TEXT NOT NULL REFERENCES sources(id),
  list_definition TEXT,          -- definition from the JLPT list (reference only)
  list_readings TEXT NOT NULL    -- JSON: readings the JLPT list teaches (primary first in practice)
);

CREATE TABLE word_forms (
  word_id TEXT NOT NULL REFERENCES words(id),
  kind TEXT NOT NULL CHECK (kind IN ('kanji', 'kana')),
  ord INTEGER NOT NULL,
  text TEXT NOT NULL,
  furigana_json TEXT,            -- [{"ruby":..,"rt":..}] for kanji forms
  applies_to TEXT,               -- JSON list: kana forms restricted to these kanji
  info TEXT NOT NULL,            -- JSON list of JMdict ke_inf/re_inf codes
  is_primary INTEGER NOT NULL,
  is_common INTEGER NOT NULL,
  accept_as_answer INTEGER NOT NULL,
  PRIMARY KEY (word_id, kind, ord)
);

CREATE TABLE senses (
  id TEXT PRIMARY KEY,           -- 'w:<seq>:<n>'
  word_id TEXT NOT NULL REFERENCES words(id),
  ord INTEGER NOT NULL,
  pos TEXT NOT NULL,             -- JSON list
  misc TEXT NOT NULL,            -- JSON list
  field TEXT NOT NULL,           -- JSON list
  info TEXT NOT NULL,            -- JSON list (s_inf)
  restricted_to TEXT NOT NULL,   -- JSON list of forms (stagk + stagr)
  gloss_en TEXT NOT NULL CHECK (gloss_en <> ''),
  gloss_th TEXT,
  note_th TEXT,
  th_status TEXT NOT NULL CHECK (th_status IN ('missing','draft','auto_checked','flagged','verified')),
  th_version INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE examples (
  id TEXT PRIMARY KEY,           -- 'ex:<tatoeba id>'
  ja TEXT NOT NULL,
  furigana_json TEXT,
  en TEXT,
  th TEXT,
  ja_author TEXT NOT NULL CHECK (ja_author <> ''),
  en_author TEXT,
  ja_license TEXT NOT NULL,
  en_license TEXT,
  source_id TEXT NOT NULL REFERENCES sources(id)
);

CREATE TABLE word_examples (
  word_id TEXT NOT NULL REFERENCES words(id),
  example_id TEXT NOT NULL REFERENCES examples(id),
  rank INTEGER NOT NULL,
  verified INTEGER NOT NULL,     -- marked as a good example in the Tatoeba index
  PRIMARY KEY (word_id, example_id)
);

CREATE TABLE kana (
  id TEXT PRIMARY KEY,           -- 'k:hira.ka'
  script TEXT NOT NULL,
  char TEXT NOT NULL,
  romaji TEXT NOT NULL,
  row TEXT NOT NULL,
  grp TEXT NOT NULL,
  ord INTEGER NOT NULL,
  source_id TEXT NOT NULL REFERENCES sources(id)
);

CREATE TABLE grammar_points (
  id TEXT PRIMARY KEY,           -- 'g:n5.012'
  jlpt_level INTEGER NOT NULL,
  ord INTEGER NOT NULL,
  title_ja TEXT NOT NULL,
  title_th TEXT NOT NULL,
  meaning_th TEXT NOT NULL,
  formation_th TEXT NOT NULL,
  notes_th TEXT,
  similar_ids TEXT NOT NULL,
  th_status TEXT NOT NULL,
  source_id TEXT NOT NULL REFERENCES sources(id)
);

CREATE TABLE grammar_examples (
  grammar_id TEXT NOT NULL REFERENCES grammar_points(id),
  example_id TEXT NOT NULL REFERENCES examples(id),
  rank INTEGER NOT NULL,
  target_span_json TEXT,
  PRIMARY KEY (grammar_id, example_id)
);

CREATE TABLE deprecations (
  old_id TEXT PRIMARY KEY,
  new_id TEXT,
  reason TEXT NOT NULL,
  content_version TEXT NOT NULL
);

CREATE INDEX idx_words_level ON words(jlpt_level, order_in_level);
CREATE INDEX idx_forms_text ON word_forms(text);
CREATE INDEX idx_senses_word ON senses(word_id, ord);
