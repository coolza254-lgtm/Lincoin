# 10 การอัปเดตในแอป

ในหน้า **ตั้งค่า → อัปเดต** มี 2 ปุ่ม ใช้ขั้นตอนตรวจไฟล์/สำรอง/ติดตั้งชุดเดียวกัน และข้อมูลการเรียนห้ามหาย

| ปุ่ม | ใช้เมื่อ | ต้องใช้เน็ต |
|---|---|---|
| **ตรวจหาอัปเดต** | ดึงเวอร์ชันใหม่จาก GitHub Releases | ใช่ (เปิด/ปิดได้ในตั้งค่า) |
| **อัปเดตจากไฟล์** | เลือกไฟล์ `.apk` หรือ `.lincoin-content` ที่อยู่ในเครื่องแล้ว (จาก Drive, USB, เบราว์เซอร์) | ไม่ |

การตัดสินใจ: **repo เป็น public** (แบบ A) และเผยแพร่ตามเงื่อนไขสัญญาอนุญาต

## อัปเดต 2 แบบ

| แบบ | อะไรเปลี่ยน | ต้องติดตั้งใหม่ | ความถี่ |
|---|---|---|---|
| **อัปเดตแอป** | โค้ด, หน้าจอ, ฟีเจอร์ | ใช่ (APK ใหม่) | เมื่อมีฟีเจอร์/แก้บั๊ก |
| **อัปเดตเนื้อหา** | `content.db` (ศัพท์, คำแปล, ไวยากรณ์, ระดับใหม่) | ไม่ต้อง สลับไฟล์ในแอป | บ่อยกว่า เช่น เพิ่ม N4 หรือแก้คำแปล |
| กฎ/ค่าตั้ง | `EngineConfig` (รางวัล, เกณฑ์) | ไม่ต้อง | มากับอัปเดตเนื้อหาได้ |

## แหล่งอัปเดต
repo `coolza254-lgtm/Lincoin` เป็น public แอปจึงอ่าน GitHub Releases ได้โดยไม่ต้องฝัง token
แต่ละ release มีไฟล์:

- `lincoin-<version>.apk` (เซ็นด้วยกุญแจเดียวกันทุกเวอร์ชัน)
- `content-<version>.lincoin-content` (zip: `content.db` + `manifest.json`)
- `latest.json`

```json
{
  "app": {
    "versionCode": 12,
    "versionName": "0.4.0",
    "apkUrl": "https://github.com/.../lincoin-0.4.0.apk",
    "sha256": "…",
    "sizeBytes": 23456789,
    "minAndroidSdk": 24,
    "changelogTh": ["เพิ่มโหมดท้าทาย", "แก้การแปลงโรมาจิ"]
  },
  "content": {
    "version": "2026.10.1",
    "url": "https://github.com/.../content-2026.10.1.lincoin-content",
    "sha256": "…",
    "sizeBytes": 18000000,
    "minAppVersionCode": 10,
    "changelogTh": ["เพิ่มศัพท์ N4 1,500 คำ"]
  }
}
```

## อัปเดตจากไฟล์ (ออฟไลน์)
- เลือกไฟล์ผ่านตัวเลือกไฟล์ของ Android แอปดูชนิดไฟล์เอง
- **ไฟล์เนื้อหา** (`.lincoin-content`) คือ zip ที่มี `content.db` + `manifest.json` (เวอร์ชัน, `sha256`, `minAppVersionCode`) แอปตรวจ hash, schema และตารางเครดิตก่อนสลับ
- **ไฟล์ APK** แอปอ่านเวอร์ชันจากไฟล์ก่อน ถ้าไม่ใหม่กว่าจะไม่ติดตั้ง แล้วสำรองข้อมูลและส่งให้ตัวติดตั้งของ Android (ลายเซ็นต้องตรงกับตัวเดิม)
- ไฟล์ใน GitHub Release ใช้ได้ทั้งสองปุ่ม จะดาวน์โหลดผ่านเบราว์เซอร์มาแล้วกด "อัปเดตจากไฟล์" ก็ได้

## ขั้นตอนในแอป (ตรวจหาอัปเดตออนไลน์)

**ปุ่ม: ตั้งค่า → อัปเดต → "ตรวจหาอัปเดต"** แสดงเวอร์ชันแอป เวอร์ชันเนื้อหา และเวลาตรวจครั้งล่าสุด
และเมื่อออนไลน์ แอปตรวจเองได้วันละครั้ง แต่ทำแค่ **ขึ้นจุดแจ้งเตือน** ไม่ติดตั้งอะไรเองโดยไม่กด

### อัปเดตแอป
1. อ่าน `latest.json` → ถ้า `versionCode` ใหม่กว่า แสดงสิ่งที่เปลี่ยน (ภาษาไทย) และขนาดไฟล์
2. กด "อัปเดต" → ดาวน์โหลด (ต่อจากเดิมได้ถ้าเน็ตหลุด, เตือนถ้าไม่ได้ใช้ Wi-Fi)
3. ตรวจ `sha256` ไม่ตรง = ลบไฟล์และแจ้ง
4. **สำรอง `user.db` อัตโนมัติ** ไปยังโฟลเดอร์สำรองของแอป (เก็บ 5 ชุดล่าสุด)
5. เปิดตัวติดตั้งของ Android (ครั้งแรกต้องอนุญาต "ติดตั้งแอปที่ไม่รู้จัก" ให้ Lincoin) Android ตรวจลายเซ็นว่าตรงกับตัวเดิม
6. เปิดแอปใหม่ → migration ฐานข้อมูล (สำรองอีกชั้นก่อน migrate) → แสดง "มีอะไรใหม่"

### อัปเดตเนื้อหา
1. ถ้า `content.version` ใหม่กว่าและแอปรองรับ (`minAppVersionCode`) แสดงสิ่งที่เปลี่ยน
2. ดาวน์โหลดไปไฟล์ชั่วคราว → ตรวจ `sha256` → เปิดตรวจ schema และตารางเครดิต
3. สลับไฟล์แบบ atomic เก็บเวอร์ชันก่อนหน้าไว้ย้อนกลับได้ 1 เวอร์ชัน
4. จับคู่ ID ตาม `deprecations` (ย้ายการ์ด / suspend รายการที่ถูกลบ ประวัติไม่หาย)
5. คำแปลที่คุณแก้เอง (`translation_overrides`) ไม่ถูกทับ

## กติกาความปลอดภัย
- ใช้ HTTPS และตรวจ `sha256` ทุกไฟล์
- ห้ามดาวน์เกรด (`versionCode` ต้องมากกว่าเดิมเสมอ)
- ไม่มีการติดตั้งเงียบ ผู้ใช้กดยืนยันทุกครั้ง
- ออฟไลน์: ปุ่มตรวจหาอัปเดตบอกว่า "ต้องต่อเน็ต หรือใช้อัปเดตจากไฟล์" แอปใช้งานต่อได้ปกติ
- ปิดการตรวจออนไลน์ได้ในตั้งค่า (`update.online_check`) แล้วแอปจะไม่ต่อเน็ตเพื่ออัปเดตเลย
- อัปเดตล้มเหลวกลางทาง: แอปเดิมยังใช้ได้ ข้อมูลไม่เปลี่ยน

## กุญแจเซ็นแอป (สำคัญมาก)
Android ยอมให้อัปเดตทับได้ **เฉพาะ APK ที่เซ็นด้วยกุญแจเดิม**
- สร้างกุญแจครั้งเดียวด้วย `tools/release/make_signing_key.sh <ไฟล์.jks>` (ต้องมี JDK) สคริปต์พิมพ์ค่า 4 ตัวที่ต้องใส่ใน GitHub → Settings → Secrets and variables → Actions:
  `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`
- `release.yml` เขียน `key.properties` จาก secrets ตอน build แล้วลบทิ้ง ถ้าไม่มี secrets workflow จะหยุด (ไม่ออก release ที่เซ็นผิดกุญแจ)
- คุณต้องเก็บ **สำเนาสำรองของไฟล์กุญแจ + รหัสผ่าน** ไว้ที่ปลอดภัย (เช่น ตัวจัดการรหัสผ่าน) ห้ามใส่ใน repo (`.gitignore` กัน `*.jks`, `key.properties` ไว้แล้ว)
- ถ้ากุญแจหาย: อัปเดตทับไม่ได้ ต้อง export ข้อมูล → ถอนแอป → ติดตั้งใหม่ → import (ข้อมูลไม่หายถ้ามีไฟล์สำรอง)
- APK จาก CI (`lincoin-test-apk` ในแต่ละ commit) เซ็นด้วยกุญแจชั่วคราว ใช้ลองเล่นเท่านั้น: อัปเดตทับ release จริงไม่ได้ ต้องส่งออกข้อมูลและถอนก่อนติดตั้ง release

## ขั้นตอนออกเวอร์ชัน (GitHub Actions)
**แอปใหม่:** แก้ `version:` ใน `app/pubspec.yaml` (เช่น `0.2.0+2`, ตัวหลัง `+` คือ `versionCode` ต้องเพิ่มทุกครั้ง) → เพิ่มหัวข้อ `## 0.2.0` ใน `CHANGELOG.md` → ติด tag `v0.2.0`

**เนื้อหาอย่างเดียว:** รอ `content.yml` สร้างเนื้อหาใหม่ลง branch `content-build` → เพิ่ม `## content <เวอร์ชัน>` ใน `CHANGELOG.md` → ติด tag `content-<เวอร์ชัน>`

`release.yml` จะ:
1. ดึง `content.db` ล่าสุดจาก branch `content-build` (`app/tool/fetch_content.sh`)
2. (tag `v*`) ตรวจว่า tag ตรงกับ `pubspec.yaml`, รัน analyze + test, build APK แบบ release และเซ็น
3. สร้าง `content-<เวอร์ชัน>.lincoin-content` และ `latest.json` พร้อม `sha256` และ changelog (`tools/release/make_release_files.py`) ถ้าเป็น release เนื้อหาอย่างเดียว ส่วน `app` ใน `latest.json` ชี้ไป APK ของ release ก่อนหน้า
4. สร้าง GitHub Release พร้อม `CREDITS.md` → แอปเห็นอัปเดตทันที (อ่านจาก `releases/latest/download/latest.json` ไม่ต้องใช้ API)

APK ที่ติดตั้งมาจะมี `content.db` ของตอน build ติดมาด้วย ใช้ได้ทันทีแบบออฟไลน์

## ผลต่อเรื่องสัญญาอนุญาต
Release บน repo public ถือเป็นการ **เผยแพร่** ข้อกำหนด Share-Alike จึงมีผลจริง
- `content.db` (รวมคำแปลไทยที่ดัดแปลงจาก JMdict) เผยแพร่ภายใต้ **CC BY-SA 4.0** พร้อมเครดิตครบ
- ห้ามคัดลอกข้อความจาก Tae Kim (CC BY-NC-SA) ลงในเนื้อหา ใช้เป็นแหล่งอ้างอิงตรวจสอบเท่านั้น เพื่อไม่ให้สัญญาอนุญาตขัดกัน
- หน้าเครดิตในแอปและไฟล์ `CREDITS.md` ใน release มาจากตาราง `sources` อัตโนมัติ

## องค์ประกอบในโค้ด
| ส่วน | ไฟล์ | หน้าที่ |
|---|---|---|
| `UpdateService` | `app/lib/services/update_service.dart` | อ่าน `latest.json`, เทียบเวอร์ชัน, ดาวน์โหลดต่อจากเดิมได้ (HTTP Range), ตรวจ `sha256` |
| `AppInstaller` | `app/lib/services/app_installer.dart` + `MainActivity.kt` | อ่านเวอร์ชันจากไฟล์ APK, ส่งให้ตัวติดตั้งของ Android ผ่าน FileProvider (`REQUEST_INSTALL_PACKAGES`) |
| `ContentStore` | `app/lib/services/content_store.dart` | ตรวจ schema/เครดิต/hash แล้วสลับ `content.db` แบบ atomic, เก็บเวอร์ชันก่อนหน้าไว้ย้อนกลับ |
| content pack | `app/lib/services/content_pack.dart` | อ่านไฟล์ `.lincoin-content` (zip + manifest) |
| `UpdateController` | `app/lib/state/update_controller.dart` | สองปุ่ม: ตรวจออนไลน์ / อัปเดตจากไฟล์, ยืนยันก่อนติดตั้งเสมอ, ตรวจเองวันละครั้ง (แค่ขึ้นจุด) |
| `BackupService` | `app/lib/services/backup_service.dart` | สำรอง `user.db` (VACUUM INTO) ก่อนอัปเดต/กู้คืน/migrate เก็บ 5 ชุดล่าสุด |
| `release.yml` | `.github/workflows/release.yml` | ทดสอบ, build, เซ็น, สร้าง manifest, ออก Release |

ไลบรารีที่ใช้ (ตรวจแล้ว): `http`, `crypto`, `path_provider`, `package_info_plus` (BSD-3), `archive`, `file_picker`, `flutter_tts`, `flutter_riverpod`, `sqlite3`, `uuid` (MIT) ตัวติดตั้ง APK เขียนเองใน `MainActivity.kt` ไม่พึ่งไลบรารีภายนอก
