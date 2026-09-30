# Lincoin app

แอป Flutter (Android) ดูโครงสร้างที่ [docs/01-architecture.md](../docs/01-architecture.md)

```sh
flutter pub get
flutter test                        # unit + widget tests
tool/fetch_content.sh               # ใส่ content.db ล่าสุดลงใน assets
flutter build apk --release
dart run ../design/gen_tokens.dart  # หลังแก้ design/tokens.json
```

ภาพหน้าจอทุกธีมสำหรับตรวจดีไซน์:
`cp <content.db> test_screens/content.db && flutter test test_screens --update-goldens`
(ผลอยู่ที่ `test_screens/out/`)
