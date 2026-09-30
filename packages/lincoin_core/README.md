# lincoin_core

เอนจินหลักของ Lincoin เขียนด้วย Dart ล้วน ไม่ขึ้นกับ Flutter หรือฐานข้อมูล จึงทดสอบและจำลองการเรียนหลายปีได้โดยไม่ต้องเปิดแอป

| โมดูล | ไฟล์ | หน้าที่ |
|---|---|---|
| Scheduler | `src/srs/scheduler.dart` | ห่อ FSRS-6 (`fsrs` 2.0.1), fuzz แบบ deterministic, replay จาก log |
| Queue | `src/srs/queue_builder.dart` | คิววันนี้: learning steps → ทบทวน (R ต่ำก่อน) → คำใหม่, ฝัง facet พี่น้อง, หยุดคำใหม่เมื่อค้างเยอะ |
| Simulator | `src/srs/simulator.dart` | จำลองภาระทบทวนตามค่าตั้ง |
| Mastery | `src/srs/mastery.dart` | เกณฑ์ "เชี่ยวชาญ" |
| Grader | `src/grading/grader.dart` | ให้คะแนนจากพฤติกรรม (ถูก/ผิด, เวลาเทียบมัธยฐานของตัวเอง, คำใบ้, เดา) |
| Kana | `src/grading/kana.dart` | แปลงโรมาจิ → คานะ, เทียบคำอ่าน |
| Economy | `src/economy/` | บัญชีลินคอย, กฎรางวัล, โหมดท้าทาย |
| Metrics | `src/metrics/metrics.dart` | ศัพท์ที่น่าจะจำได้, coverage, retention จริง, calibration, log-loss |
| Config | `src/config/engine_config.dart` | กฎทั้งหมดเป็น JSON มีเวอร์ชัน |

```sh
dart pub get
dart test                  # ชุดทดสอบทั้งหมด รวมจำลอง 3 ปี
dart run tool/simulate.dart  # ตารางภาระทบทวนตามค่าตั้ง
```
