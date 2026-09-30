// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppLocalizationsTh extends AppLocalizations {
  AppLocalizationsTh([String locale = 'th']) : super(locale);

  @override
  String get tabHome => 'หน้าหลัก';

  @override
  String get tabPractice => 'ฝึก & ท้าทาย';

  @override
  String get tabStats => 'สถิติ';

  @override
  String get tabShop => 'ร้าน';

  @override
  String get settings => 'ตั้งค่า';

  @override
  String get close => 'ปิด';

  @override
  String get cancel => 'ยกเลิก';

  @override
  String get confirm => 'ยืนยัน';

  @override
  String get save => 'บันทึก';

  @override
  String get delete => 'ลบ';

  @override
  String get send => 'ส่ง';

  @override
  String get next => 'ต่อไป';

  @override
  String get none => 'ไม่มี';

  @override
  String get never => 'ยังไม่เคย';

  @override
  String get options => 'ตัวเลือก';

  @override
  String get required => 'กรุณากรอก';

  @override
  String get invalidNumber => 'ตัวเลขไม่ถูกต้อง';

  @override
  String get noContentTitle => 'ยังไม่มีเนื้อหา';

  @override
  String get noContentBody =>
      'แอปนี้ยังไม่มีชุดคำศัพท์ ติดตั้งได้จากหน้าอัปเดต (ออนไลน์ หรือจากไฟล์ .lincoin-content)';

  @override
  String get goToUpdates => 'ไปหน้าอัปเดต';

  @override
  String get vocabDeck => 'ท่องศัพท์';

  @override
  String get grammarDeck => 'ไวยากรณ์';

  @override
  String comingInPhase(int phase) {
    return 'เร็วๆ นี้ (เฟส $phase)';
  }

  @override
  String get dueLabel => 'ต้องทบทวน';

  @override
  String get newLabel => 'ใหม่';

  @override
  String get minutesLabel => 'นาที (ประมาณ)';

  @override
  String get newPausedBacklog => 'พักคำใหม่ไว้ก่อน เพราะการ์ดค้างเยอะ';

  @override
  String get startStudy => 'เริ่มเรียน';

  @override
  String get allDoneToday => 'วันนี้ครบแล้ว 🎉';

  @override
  String get coverageTitle => 'ความครอบคลุม';

  @override
  String get coverageHelp =>
      'สัดส่วนของคำในแต่ละระดับที่น่าจะจำได้ตอนนี้ (คำนวณจากความน่าจะเป็นที่จะจำได้ของแต่ละคำ)';

  @override
  String get levelKana => 'คานะ';

  @override
  String get newKana => 'ตัวอักษรใหม่';

  @override
  String get newWord => 'คำใหม่';

  @override
  String get introHint =>
      'ดูให้คุ้นตา แล้วจะมีคำถามเกี่ยวกับคำนี้ในอีกไม่กี่ข้อ';

  @override
  String get gotIt => 'จำแล้ว ไปต่อ';

  @override
  String get hiragana => 'ฮิรางานะ';

  @override
  String get katakana => 'คาตาคานะ';

  @override
  String get untranslated => '(ยังไม่มีคำแปลไทย แสดงต้นฉบับภาษาอังกฤษ)';

  @override
  String moreMeanings(int count) {
    return 'และอีก $count ความหมาย';
  }

  @override
  String exampleCredit(String number, String author, String license) {
    return 'ประโยค Tatoeba #$number โดย $author · $license';
  }

  @override
  String get listen => 'ฟังเสียง';

  @override
  String get noJapaneseVoice =>
      'เครื่องนี้ยังไม่มีเสียงภาษาญี่ปุ่น ติดตั้งได้ที่ ตั้งค่า Android → การแปลงข้อความเป็นเสียง';

  @override
  String get qMeaning => 'ความหมายคืออะไร';

  @override
  String get qTypeReading => 'พิมพ์คำอ่าน';

  @override
  String get qTypeRomaji => 'พิมพ์โรมาจิ';

  @override
  String get kanaPreview => 'คานะที่พิมพ์';

  @override
  String hintStartsWith(String kana) {
    return 'ขึ้นต้นด้วย $kana';
  }

  @override
  String get synonymTryAgain =>
      'คำนี้ความหมายเดียวกัน แต่เราต้องการอีกคำ ลองอีกครั้ง';

  @override
  String get checkAnswer => 'ตรวจคำตอบ';

  @override
  String get guessing => 'ตอบแบบเดา';

  @override
  String get guessingHelp =>
      'เลือกไว้ถ้าไม่แน่ใจ การ์ดจะกลับมาเร็วขึ้น และไม่นับว่าจำได้';

  @override
  String get hint => 'คำใบ้';

  @override
  String get dontKnow => 'ไม่รู้';

  @override
  String get correct => 'ถูกต้อง';

  @override
  String get notYet => 'ยังไม่ถูก';

  @override
  String yourAnswer(String answer) {
    return 'คำตอบของคุณ: $answer';
  }

  @override
  String get willReviewSoon => 'ไม่เป็นไร คำนี้จะกลับมาให้ทบทวนเร็วๆ นี้';

  @override
  String get graduated => 'จำคำนี้ได้แล้ว จะเว้นช่วงทบทวนให้นานขึ้น';

  @override
  String get masteredNow => 'คำนี้อยู่ในระดับเชี่ยวชาญแล้ว';

  @override
  String get leechNote => 'คำนี้ลืมบ่อย ลองดูประโยคตัวอย่างหรือจำวิธีอื่นดู';

  @override
  String get reportTranslation => 'รายงานคำแปล';

  @override
  String get reportHint => 'คำแปลผิดอย่างไร หรือควรเป็นอะไร (ไม่บังคับ)';

  @override
  String get reportSaved => 'บันทึกแล้ว ขอบคุณครับ';

  @override
  String get nothingToStudy => 'ไม่มีการ์ดให้เรียนตอนนี้';

  @override
  String get sessionDone => 'จบรอบนี้แล้ว';

  @override
  String get answeredLabel => 'ข้อ';

  @override
  String get accuracyLabel => 'ถูก';

  @override
  String get coinsEarned => 'ได้ลินคอย';

  @override
  String get bonusDailyClear => 'โบนัสเคลียร์การ์ดวันนี้';

  @override
  String get bonusCoverage => 'โบนัสความครอบคลุม';

  @override
  String laterSteps(int count) {
    return 'มีการ์ดที่กำลังเรียนอีก $count ใบ จะกลับมาให้ทบทวนภายหลังวันนี้';
  }

  @override
  String get backHome => 'กลับหน้าหลัก';

  @override
  String get sectionStudy => 'การเรียน';

  @override
  String get sectionLook => 'หน้าตา';

  @override
  String get sectionApp => 'แอป';

  @override
  String get targetRetention => 'เป้าหมายการจำ';

  @override
  String get targetRetentionHelp =>
      'โอกาสจำได้ตอนถึงรอบทบทวน สูงขึ้น = ทบทวนบ่อยขึ้นมาก (90% เหมาะกับส่วนใหญ่)';

  @override
  String get newPerDay => 'การ์ดใหม่ต่อวัน';

  @override
  String get newPerDayHelp =>
      '1 คำมี 2 การ์ด (ความหมาย และคำอ่าน) การ์ดใหม่ทำให้งานทบทวนในอนาคตเพิ่มขึ้น';

  @override
  String get includeKana => 'เริ่มจากคานะ';

  @override
  String get includeKanaHelp => 'ปิดถ้าอ่านฮิรางานะ/คาตาคานะได้แล้ว';

  @override
  String get furiganaMode => 'ฟุริงานะ';

  @override
  String get furiganaAlways => 'แสดงเสมอ';

  @override
  String get furiganaHideMastered => 'ซ่อนคำที่เชี่ยวชาญแล้ว';

  @override
  String get furiganaNever => 'ซ่อนทั้งหมด';

  @override
  String get dayStart => 'เริ่มวันใหม่เวลา';

  @override
  String dayStartHelp(int hour) {
    return 'เรียนหลังเที่ยงคืนก่อน 0$hour:00 ยังนับเป็นวันก่อนหน้า';
  }

  @override
  String get theme => 'ธีม';

  @override
  String get reduceMotion => 'ลดแอนิเมชัน';

  @override
  String get updates => 'อัปเดต';

  @override
  String get backup => 'สำรองข้อมูล';

  @override
  String get credits => 'เครดิตและสัญญาอนุญาต';

  @override
  String get appVersion => 'เวอร์ชันแอป';

  @override
  String get contentVersion => 'เวอร์ชันเนื้อหา';

  @override
  String get lastChecked => 'ตรวจล่าสุด';

  @override
  String get checkForUpdates => 'ตรวจหาอัปเดต';

  @override
  String get updateFromFile => 'อัปเดตจากไฟล์';

  @override
  String get updateFromFileHelp =>
      'เลือกไฟล์ .apk (แอป) หรือ .lincoin-content (เนื้อหา) ที่อยู่ในเครื่องแล้ว ไม่ต้องใช้เน็ต';

  @override
  String get upToDate => 'เป็นเวอร์ชันล่าสุดแล้ว';

  @override
  String newAppVersion(String version) {
    return 'แอปเวอร์ชันใหม่ $version';
  }

  @override
  String newContentVersion(String version) {
    return 'เนื้อหาเวอร์ชันใหม่ $version';
  }

  @override
  String get updateApp => 'อัปเดตแอป';

  @override
  String get updateContent => 'อัปเดตเนื้อหา';

  @override
  String get contentNeedsNewerApp =>
      'มีเนื้อหาใหม่ที่ต้องใช้แอปเวอร์ชันใหม่กว่า อัปเดตแอปก่อน';

  @override
  String get onlineCheck => 'ตรวจอัปเดตออนไลน์';

  @override
  String get onlineCheckHelp =>
      'ปิดแล้วแอปจะไม่ใช้เน็ตเพื่ออัปเดตเลย (ยังอัปเดตจากไฟล์ได้)';

  @override
  String rollbackContent(String version) {
    return 'ย้อนกลับเป็นเนื้อหา $version';
  }

  @override
  String get rollbackHelp =>
      'ความก้าวหน้าไม่หาย การ์ดของคำที่ไม่มีในเวอร์ชันนั้นจะถูกพักไว้';

  @override
  String get updateSafety =>
      'ก่อนอัปเดตทุกครั้งแอปจะสำรองข้อมูลการเรียนอัตโนมัติ ทุกไฟล์ตรวจด้วย sha256 และไม่มีการติดตั้งโดยไม่กดยืนยัน';

  @override
  String installAppFromFile(String version) {
    return 'ติดตั้งแอปเวอร์ชัน $version?';
  }

  @override
  String get installAppFromFileHelp =>
      'แอปจะสำรองข้อมูลก่อน แล้วเปิดตัวติดตั้งของ Android (ไฟล์ต้องเซ็นด้วยกุญแจเดียวกับแอปที่ติดตั้งอยู่)';

  @override
  String installContentFromFile(String version) {
    return 'ติดตั้งเนื้อหาเวอร์ชัน $version?';
  }

  @override
  String installedContent(String version) {
    return 'ที่ติดตั้งอยู่: $version';
  }

  @override
  String get backupHelp =>
      'ข้อมูลการเรียน ลินคอย และรางวัลทั้งหมดอยู่ในไฟล์เดียว ส่งออกเก็บไว้ใน Drive หรือเครื่องอื่นได้ แอปสำรองให้อัตโนมัติก่อนอัปเดตทุกครั้ง';

  @override
  String get exportBackup => 'ส่งออกไฟล์สำรอง';

  @override
  String get importBackup => 'นำเข้าไฟล์สำรอง';

  @override
  String get exported => 'บันทึกไฟล์สำรองแล้ว';

  @override
  String get exportCancelled => 'ยกเลิกการบันทึก';

  @override
  String get autoBackups => 'สำรองในเครื่อง (5 ชุดล่าสุด)';

  @override
  String get noBackups => 'ยังไม่มี';

  @override
  String get restore => 'กู้คืน';

  @override
  String get restoreConfirmTitle => 'กู้คืนข้อมูลจากไฟล์นี้?';

  @override
  String get restoreConfirmBody =>
      'ข้อมูลปัจจุบันจะถูกแทนที่ (แอปจะสำรองข้อมูลปัจจุบันไว้ก่อน ย้อนกลับได้)';

  @override
  String get restored => 'กู้คืนแล้ว';

  @override
  String get reasonBeforeUpdate => 'ก่อนอัปเดตแอป';

  @override
  String get reasonBeforeContent => 'ก่อนอัปเดตเนื้อหา';

  @override
  String get reasonBeforeMigrate => 'ก่อนปรับฐานข้อมูล';

  @override
  String get reasonBeforeRestore => 'ก่อนกู้คืน';

  @override
  String get reasonManual => 'สำรองเอง';

  @override
  String versionLine(String app, String content) {
    return 'แอป $app · เนื้อหา $content';
  }

  @override
  String get contentSources => 'แหล่งเนื้อหา';

  @override
  String get contentLicenseNote =>
      'เนื้อหาในแอป (รวมคำแปลไทยที่ดัดแปลงจาก JMdict) เผยแพร่ภายใต้ CC BY-SA 4.0 ประโยคตัวอย่างจาก Tatoeba แสดงชื่อผู้เขียนทุกประโยค';

  @override
  String get fonts => 'ฟอนต์';

  @override
  String get softwareLicenses => 'สัญญาอนุญาตซอฟต์แวร์';

  @override
  String get expectedKnown => 'คำที่น่าจะจำได้ตอนนี้';

  @override
  String get expectedKnownHelp =>
      'ผลรวมความน่าจะเป็นที่จะจำได้ของทุกคำ ไม่ใช่แค่จำนวนคำที่เคยเห็น';

  @override
  String get itemsStarted => 'เริ่มเรียนแล้ว';

  @override
  String get masteredItems => 'เชี่ยวชาญ';

  @override
  String get minutes7Days => 'นาที (7 วัน)';

  @override
  String get retentionTitle => 'การจำจริง (30 วัน)';

  @override
  String targetIs(int percent) {
    return 'เป้าหมาย $percent%';
  }

  @override
  String retentionHelp(int n) {
    return 'สัดส่วนที่ตอบถูกเมื่อถึงรอบทบทวน จาก $n ครั้ง ถ้าใกล้เป้าหมาย แปลว่าตารางทบทวนแม่นยำ';
  }

  @override
  String get smallSample => 'ข้อมูลยังน้อย ตัวเลขอาจแกว่ง';

  @override
  String levelLine(String known, int total, int mastered) {
    return 'จำได้ ~$known/$total · เชี่ยวชาญ $mastered';
  }

  @override
  String get activity14 => 'การทบทวน 14 วันล่าสุด';

  @override
  String get activityHelp => 'แท่งเข้ม = ตอบถูก แท่งอ่อน = ทั้งหมด';

  @override
  String get forecast7 => 'การ์ดที่จะถึงรอบ 7 วันข้างหน้า';

  @override
  String get forecastHelp => 'รวมการ์ดค้างไว้ในวันนี้';

  @override
  String get today => 'วันนี้';

  @override
  String get calibration => 'ความแม่นของการคาดการณ์';

  @override
  String calibrationHelp(String logLoss) {
    return 'เทียบโอกาสจำที่ระบบคาด (แถว) กับที่จำได้จริง (แถบ) ค่า log loss $logLoss ยิ่งต่ำยิ่งดี';
  }

  @override
  String leeches(int count) {
    return 'คำที่ลืมบ่อย $count คำ';
  }

  @override
  String totalReviews(int count) {
    return 'ทบทวนไปแล้วทั้งหมด $count ครั้ง';
  }

  @override
  String get balance => 'ยอดลินคอย';

  @override
  String get avgPerDay => 'ได้เฉลี่ย/วัน (7 วัน)';

  @override
  String get noRewardsTitle => 'ยังไม่มีรางวัล';

  @override
  String get noRewardsBody =>
      'ตั้งรางวัลให้ตัวเอง เช่น ชานม 1 แก้ว ดูหนัง 1 เรื่อง แล้วใช้ลินคอยแลก';

  @override
  String get addReward => 'เพิ่มรางวัล';

  @override
  String get editReward => 'แก้ไขรางวัล';

  @override
  String get emoji => 'ไอคอน';

  @override
  String get rewardTitle => 'ชื่อรางวัล';

  @override
  String get price => 'ราคา (ลินคอย)';

  @override
  String get priceHelp => 'ทบทวนครบทุกวันได้ราว 50–150 ลินคอย/วัน';

  @override
  String get repeatable => 'แลกได้หลายครั้ง';

  @override
  String get cooldownDays => 'เว้นระยะกี่วันต่อครั้ง (ไม่บังคับ)';

  @override
  String get oneTime => 'ครั้งเดียว';

  @override
  String everyNDays(int days) {
    return 'ทุก $days วัน';
  }

  @override
  String get readyToRedeem => 'แลกได้แล้ว!';

  @override
  String needMore(int amount) {
    return 'อีก $amount ลินคอย';
  }

  @override
  String cooldownUntil(String date) {
    return 'แลกได้อีกครั้ง $date';
  }

  @override
  String get alreadyRedeemed => 'แลกไปแล้ว';

  @override
  String get redeem => 'แลก';

  @override
  String redeemConfirm(int price) {
    return 'ใช้ $price ลินคอย แลกรางวัลนี้?';
  }

  @override
  String redeemed(String title) {
    return 'แลก $title แล้ว ขอให้สนุก!';
  }

  @override
  String get redeemHistory => 'ประวัติการแลก';

  @override
  String get practiceTitle => 'โหมดฝึก';

  @override
  String get practiceBody =>
      'เล่นได้ไม่จำกัดจากคำที่เรียนแล้ว ได้ลินคอยแบบลดหลั่น ไม่กระทบตารางทบทวน';

  @override
  String get challengeTitle => 'โหมดท้าทาย';

  @override
  String get challengeBody =>
      'เดิมพันลินคอยกับเป้าหมายที่ปรับตามฝีมือ ชนะได้ถึง 6 เท่า';
}
