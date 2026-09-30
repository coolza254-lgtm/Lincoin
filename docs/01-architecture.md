# 01 สถาปัตยกรรม

## เทคโนโลยี

| ส่วน | เลือกใช้ | เหตุผล |
|---|---|---|
| Framework | Flutter (Dart) | UI/แอนิเมชันดี, build APK ได้, codebase เดียวรองรับ iOS ภายหลังถ้าต้องการ |
| ฐานข้อมูล | SQLite ผ่านแพ็กเกจ `sqlite3` (SQL ตรง ไม่ใช้ code generation) | query สถิติซับซ้อนได้, ใช้ schema เดียวกับ content builder, migration เป็นรายการ SQL มีเวอร์ชัน (`PRAGMA user_version`) |
| State management | Riverpod | แยก logic ออกจาก UI, ทดสอบง่าย |
| SRS | ไลบรารี FSRS (ดู [04](04-srs-fsrs.md)) ห่อด้วย interface ของเราเอง | สลับไลบรารี/เวอร์ชันได้ |
| เสียง | TTS ภาษาญี่ปุ่นของเครื่อง (`flutter_tts`) | ออฟไลน์ได้ถ้าเครื่องมีเสียงญี่ปุ่น |
| แจ้งเตือน | Local notifications | ไม่ต้องใช้เน็ต |
| ฟอนต์ | ฟอนต์สัญญาอนุญาต OFL (เช่น Noto Sans JP, Zen Maru Gothic) | ใส่เครดิตในหน้าเครดิต |

## โครงสร้างแบบชั้น

```
┌──────────────────────────────────────────────┐
│ UI: หน้าจอ, ธีม, แอนิเมชัน                    │
├──────────────────────────────────────────────┤
│ Features: vocab | grammar | practice |       │
│           challenge | shop | stats | settings│
├──────────────────────────────────────────────┤
│ Core engines (Dart ล้วน ไม่พึ่ง Flutter)      │
│  • Scheduler (FSRS wrapper)                  │
│  • Grader (ให้คะแนนจากพฤติกรรม)               │
│  • Economy (ledger ลินคอย, กฎรางวัล)          │
│  • Metrics (คำนวณสถิติจาก log)               │
│  • Question generator (สร้างโจทย์/ตัวลวง)     │
├──────────────────────────────────────────────┤
│ Data: repositories                           │
│  • content.db (อ่านอย่างเดียว)                │
│  • user.db (ข้อมูลผู้ใช้)                     │
│  • Sync adapter (interface ว่างไว้ก่อน)       │
└──────────────────────────────────────────────┘
```

Core engines เป็น Dart ล้วน จึงทดสอบหน่วย (unit test) และรันจำลองหลายปีได้โดยไม่ต้องเปิดแอป

## โครงสร้างโฟลเดอร์

```
packages/lincoin_core/  engines เป็น Dart ล้วน (scheduler, grader, economy, metrics,
                        question generator, session queue) + ชุดทดสอบ
app/                    แอป Flutter
  lib/
    data/               user.db (schema + migrations), content.db reader, repositories
    services/           study, stats, backup, content store, updates, TTS
    state/              Riverpod providers, update controller
    features/           หน้าจอแยกตามแท็บ/โหมด (home, study, stats, shop, practice, settings)
    ui/                 design system: tokens.g.dart (สร้างจาก design/tokens.json), theme, components
    l10n/               ข้อความ UI (app_th.arb)
  test/                 unit + widget tests (ใช้ schema จริงของ content builder)
  test_screens/         ภาพหน้าจอทุกธีมสำหรับตรวจดีไซน์ (ไม่รันใน CI)
  tool/fetch_content.sh ดึง content.db ล่าสุดมาใส่ใน APK
design/                 tokens.json, ตัวตรวจคอนทราสต์, ตัวสร้าง theme
tools/
  content_builder/      สร้าง content.db จากไฟล์ต้นทาง
  translations/         คำแปลไทย + สถานะการตรวจ
  release/              สร้าง content pack + latest.json สำหรับ GitHub Release
  brand/                โลโก้ต้นฉบับ + สคริปต์สร้างไอคอนแอป
docs/
```

## หลักการเพื่อใช้งานระยะยาว

1. **แยกเนื้อหา / ข้อมูลผู้ใช้ / ตรรกะ** อัปเดตเนื้อหาโดยเปลี่ยน `content.db` ทั้งไฟล์ ไม่แตะความก้าวหน้า
2. **ID ตายตัว** เชื่อมระหว่างสองฐานข้อมูล (`w:<JMdict ent_seq>`, `g:n5.012`)
3. **Log แบบเพิ่มอย่างเดียว** ทุกสถิติและสถานะการ์ดสร้างใหม่ได้จาก log
4. **กฎเป็นข้อมูล** ค่ารางวัล, เกณฑ์ mastered, ตัวคูณท้าทาย เก็บใน config มีเวอร์ชัน
5. **Migration ทุกเวอร์ชัน** และสำรอง `user.db` อัตโนมัติก่อน migrate
6. **Backup/Export** ส่งออก/นำเข้าไฟล์ได้จากหน้าตั้งค่า
7. **เตรียมซิงก์** ทุกแถวใน user.db มี UUID และเวลาแก้ไข แต่ยังไม่สร้างเซิร์ฟเวอร์

## ฟีเจอร์ที่ใช้เน็ต
- **ปุ่มอัปเดตในแอป** (แอป + เนื้อหา) จาก GitHub Releases ดู [10-updates.md](10-updates.md) (มีตั้งแต่ MVP)
- Cloud backup/ซิงก์หลายเครื่อง
- (ทางเลือก) AI อธิบายเพิ่มเติม ต้องมีค่า API และจัดการคีย์อย่างปลอดภัย

## ข้อจำกัดที่ทราบ
- Build iOS ต้องใช้ Mac/Xcode ไม่อยู่ในขอบเขตตอนนี้
- เสียง TTS ขึ้นกับเครื่อง ถ้าไม่มีเสียงญี่ปุ่นต้องดาวน์โหลดในการตั้งค่า Android
