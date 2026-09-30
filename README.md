# Lincoin

แอป Android สำหรับเรียนภาษาญี่ปุ่นใช้เองส่วนตัว ตั้งแต่ระดับเริ่มต้นจนถึง N1 เน้นท่องศัพท์และเรียนไวยากรณ์ด้วยระบบทบทวนแบบเว้นระยะ (FSRS) มีเกมเล็กน้อยด้วยเหรียญ **Lincoin**

- ใช้ออฟไลน์เป็นหลัก ใช้เน็ตเฉพาะบางฟีเจอร์
- วัดผลจากข้อมูลการตอบจริง ไม่ให้คะแนนตามความรู้สึก
- ใช้เนื้อหาจากแหล่งที่มีสัญญาอนุญาตชัดเจน และแสดงเครดิตเสมอ

สถานะ: **เฟส 4 (แอป MVP: ท่องศัพท์คานะ + N5, สถิติ, ร้านรางวัล, สำรองข้อมูล, ปุ่มอัปเดต)** เอกสารทั้งหมดอยู่ที่ [`docs/`](docs/README.md)

## โครงสร้าง repo

| โฟลเดอร์ | เนื้อหา |
|---|---|
| `docs/` | เอกสารออกแบบ |
| `packages/lincoin_core/` | เอนจินหลัก (FSRS, ให้คะแนน, Lincoin, สถิติ) พร้อมชุดทดสอบ |
| `design/` | Design tokens (ธีม, สี, ฟอนต์) และตัวตรวจคอนทราสต์ |
| `app/` | แอป Flutter (Android) |
| `tools/content_builder/` | สร้าง `content.db` จากข้อมูลเปิด (รันจริงบน GitHub Actions) |
| `tools/translations/` | คำแปลไทยและการตรวจคุณภาพ |
| `tools/release/` | สร้างไฟล์สำหรับ GitHub Release และกุญแจเซ็นแอป |

## รันทดสอบ

ต้องมี [Dart SDK](https://dart.dev/get-dart) 3.5 ขึ้นไป

```sh
cd packages/lincoin_core && dart pub get && dart test
dart run design/check_tokens.dart

# แอป (ต้องมี Flutter 3.47+)
cd app && flutter pub get && flutter test
tool/fetch_content.sh          # ใส่เนื้อหาล่าสุดลงใน APK
flutter build apk --release
```

## ติดตั้งและอัปเดต
ดาวน์โหลด `lincoin-<เวอร์ชัน>.apk` จากหน้า Releases แล้วติดตั้ง จากนั้นอัปเดตได้จากในแอป
(ตั้งค่า → อัปเดต) ดูรายละเอียดที่ [docs/10-updates.md](docs/10-updates.md)
