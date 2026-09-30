# content_builder

สร้าง `content.db` จากข้อมูลเปิดที่มีสัญญาอนุญาต ใช้ Python 3.11 ไลบรารีมาตรฐานเท่านั้น

```sh
python -m lincoin_content fetch --levels n5     # ดาวน์โหลดแหล่งข้อมูลลง .cache/ (บันทึก sha256)
python -m lincoin_content build --levels n5     # สร้าง build/content.db, report.json, CREDITS.md
python -m unittest discover -s tests            # ทดสอบด้วย fixtures (ไม่ต้องใช้เน็ต)
```

- แหล่งข้อมูลทั้งหมดและเครดิตอยู่ใน `sources.json` แหล่งที่ไม่มีสัญญาอนุญาตหรือข้อความเครดิตจะโหลดไม่ผ่าน
- ทุกแถวในฐานข้อมูลผูกกับแหล่งที่มา และ `checks.py` ทำให้ build ล้มเมื่อขาดเครดิต/ผู้เขียนประโยค/ข้อมูลไม่ครบ
- การดึงข้อมูลจริงรันบน GitHub Actions (`.github/workflows/content.yml`) ผลลัพธ์อยู่ใน artifact ของ workflow
- คำแปลไทยยังไม่อยู่ในเฟสนี้ (`th_status = 'missing'`) จะเพิ่มในเฟส 3
