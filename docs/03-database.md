# 03 ฐานข้อมูล

สองไฟล์แยกกัน เชื่อมด้วย ID ตายตัว ไม่มี foreign key ข้ามไฟล์

## content.db (อ่านอย่างเดียว เปลี่ยนทั้งไฟล์เมื่ออัปเดต)

```sql
meta(key TEXT PK, value TEXT)
  -- content_version, schema_version, built_at

sources(
  id TEXT PK, name, url, license, license_url,
  attribution_text, version, retrieved_at, checksum)

words(
  id TEXT PK,                 -- 'w:<JMdict ent_seq>'
  jlpt_level INT NULL,        -- 5..1 ประมาณการ
  jlpt_source_id TEXT,
  order_in_level INT,         -- ลำดับการสอน
  pos TEXT, tags TEXT,
  source_id TEXT)

word_forms(
  word_id, kind,              -- 'kanji' | 'kana'
  text, reading_kana, furigana_json,
  is_primary BOOL, is_common BOOL)

senses(
  id TEXT PK, word_id, ord,
  gloss_en TEXT,              -- ต้นฉบับ JMdict
  gloss_th TEXT, note_th TEXT NULL,
  th_status TEXT,             -- draft | auto_checked | flagged | verified
  th_version INT)

examples(
  id TEXT PK,                 -- 'ex:<tatoeba id>'
  ja, furigana_json, en, th,
  ja_author, en_author, source_id, license)

word_examples(word_id, example_id, rank)

kana(
  id TEXT PK,                 -- 'k:hira.a'
  script, char, romaji, row, ord)

grammar_points(
  id TEXT PK,                 -- 'g:n5.012'
  jlpt_level, ord,
  title_ja, title_th, meaning_th,
  formation_th, notes_th,
  similar_ids TEXT,           -- หัวข้อที่ควรเทียบความต่าง
  th_status, source_id)

grammar_examples(
  grammar_id, example_id, rank,
  target_span_json)           -- ตำแหน่งส่วนไวยากรณ์ในประโยค (ใช้ทำโจทย์เติมคำ)

deprecations(old_id, new_id NULL, reason, content_version)
```

## user.db (ข้อมูลผู้ใช้ ห้ามหาย)

```sql
meta(key, value)              -- schema_version, device_id, content_version_seen

settings(key, value)          -- ดู "ค่าตั้งค่า" ด้านล่าง

cards(
  id TEXT PK,                 -- '<item_id>#<facet>'
  item_id, deck,              -- deck: 'vocab' | 'grammar'
  facet,                      -- recog | recall | listen | cloze | kana
  status,                     -- new | learning | review | relearning | suspended
  due_at, stability, difficulty,
  step_index INT,             -- ตำแหน่งใน learning steps
  reps, lapses, last_review_at,
  introduced_at, first_mastered_at,
  is_leech BOOL,
  uuid, updated_at)

review_log(                   -- append-only, ป้อน FSRS
  id UUID PK, card_id, deck, session_id,
  ts_utc, tz_offset_min, study_day,   -- study_day ตัดวันที่ 04:00
  question_type, answer_raw,
  is_correct, used_hint, marked_guess,
  response_ms, rating,                -- 1..4 จาก Grader
  elapsed_days,
  s_before, d_before, s_after, d_after,
  due_after, r_predicted,             -- ใช้ทำกราฟ calibration
  params_version, algo_version)

practice_log(                 -- โหมดฝึก/ท้าทาย ไม่ป้อน FSRS
  id UUID PK, card_id, session_id, mode,   -- practice | challenge
  ts_utc, question_type, is_correct, response_ms)

sessions(
  id UUID PK, mode, started_at, ended_at,
  active_seconds, summary_json)

fsrs_params(
  id, deck, version, weights_json,
  desired_retention, created_at,
  log_loss_before, log_loss_after, is_active)

daily_stats(                  -- แคช สร้างใหม่ได้จาก log
  study_day, deck, new_count, review_count, correct_count,
  practice_count, active_seconds, coins_earned)

coin_ledger(
  id UUID PK, ts_utc, delta INT, reason, ref_id,
  idempotency_key TEXT UNIQUE, note)
  -- ยอดคงเหลือ = SUM(delta)

rewards(                      -- ร้านรางวัลจริงที่ผู้ใช้ตั้ง
  id UUID PK, title, emoji, price,
  repeatable BOOL, cooldown_days INT NULL,
  condition_json NULL, active BOOL, created_at)

redemptions(id UUID PK, reward_id, ledger_id, ts_utc, note)

challenges(                   -- ประวัติโหมดท้าทาย
  id UUID PK, type, tier, stake, multiplier,
  target_json, started_at, finished_at,
  result,                     -- won | lost | forfeited | active
  stake_ledger_id, payout_ledger_id)

config_versions(key, version, json, activated_at)  -- กฎรางวัล/เกณฑ์ที่ใช้อยู่

translation_overrides(sense_id PK, gloss_th, note_th, updated_at)
content_reports(id UUID PK, item_id, kind, comment, created_at, resolved)
```

## ค่าตั้งค่า (settings)

| key | ค่าเริ่มต้น | ช่วง |
|---|---|---|
| `vocab.desired_retention` | 0.90 | 0.80–0.95 |
| `grammar.desired_retention` | 0.90 | 0.80–0.95 |
| `vocab.new_per_day` | 10 | 0–50 |
| `grammar.new_per_day` | 2 | 0–10 |
| `vocab.facets` | recog, recall | + listen |
| `day_start_hour` | 4 | 0–6 |
| `reminder_time` | 20:00 | |
| `update.online_check` | true | true/false |

## นโยบาย
- **Migration:** Drift schema version, สำรอง `user.db` ก่อน migrate ทุกครั้ง, มีทดสอบ migration ทุกเวอร์ชัน
- **อัปเดตเนื้อหา:** เทียบ ID กับ `deprecations` ถ้า ID ถูกย้ายให้ย้ายการ์ด ถ้าถูกลบให้ suspend การ์ดแต่เก็บประวัติ
- **Export:** ไฟล์ `user.db` ทั้งไฟล์ + ทางเลือก JSON
