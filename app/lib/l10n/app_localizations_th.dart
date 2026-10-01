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
  String get coinsEarned => 'ได้ Lincoin';

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
      'ข้อมูลการเรียน Lincoin และรางวัลทั้งหมดอยู่ในไฟล์เดียว ส่งออกเก็บไว้ใน Drive หรือเครื่องอื่นได้ แอปสำรองให้อัตโนมัติก่อนอัปเดตทุกครั้ง';

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
  String get balance => 'ยอด Lincoin';

  @override
  String get avgPerDay => 'ได้เฉลี่ย/วัน (7 วัน)';

  @override
  String get noRewardsTitle => 'ยังไม่มีรางวัล';

  @override
  String get noRewardsBody =>
      'ตั้งรางวัลให้ตัวเอง เช่น ชานม 1 แก้ว ดูหนัง 1 เรื่อง แล้วใช้ Lincoin แลก';

  @override
  String get addReward => 'เพิ่มรางวัล';

  @override
  String get editReward => 'แก้ไขรางวัล';

  @override
  String get emoji => 'ไอคอน';

  @override
  String get rewardTitle => 'ชื่อรางวัล';

  @override
  String get price => 'ราคา (Lincoin)';

  @override
  String get priceHelp => 'ทบทวนครบทุกวันได้ราว 50–150 Lincoin/วัน';

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
    return 'อีก $amount Lincoin';
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
    return 'ใช้ $price Lincoin แลกรางวัลนี้?';
  }

  @override
  String redeemed(String title) {
    return 'แลก $title แล้ว ขอให้สนุก!';
  }

  @override
  String get redeemHistory => 'ประวัติการแลก';

  @override
  String get practiceTitle => 'ฝึก';

  @override
  String get practiceBody =>
      'เล่นได้ไม่จำกัดจากคำที่เรียนแล้ว รอบละ 10 ข้อ ไม่กระทบตารางทบทวน ได้ Lincoin แบบลดหลั่นต่อวัน';

  @override
  String get challengeTitle => 'ท้าทาย';

  @override
  String get challengeBody =>
      'เดิมพัน Lincoin กับเป้าหมายที่ปรับตามฝีมือคุณเอง ชนะได้คืนทุนพร้อมกำไร แพ้เสียเดิมพัน ออกกลางคันถือว่าแพ้';

  @override
  String get qChooseWord => 'เลือกคำภาษาญี่ปุ่น';

  @override
  String get qChooseRomaji => 'อ่านว่าอะไร';

  @override
  String get learnedItems => 'เรียนแล้ว';

  @override
  String get weakItems => 'จุดอ่อน';

  @override
  String get recentItems => 'ใหม่ (7 วัน)';

  @override
  String practiceRate(int percent) {
    return 'ได้จากการฝึกวันนี้ · อัตราตอนนี้ $percent%';
  }

  @override
  String get startPractice => 'เริ่มฝึก 10 ข้อ';

  @override
  String get practiceNeedsItems => 'เรียนอย่างน้อย 4 คำก่อน แล้วค่อยมาฝึก';

  @override
  String get practiceDone => 'จบรอบฝึกแล้ว';

  @override
  String get correctCount => 'ตอบถูก';

  @override
  String get bestCombo => 'คอมโบสูงสุด';

  @override
  String combo(int n) {
    return 'คอมโบ $n';
  }

  @override
  String get done => 'เสร็จ';

  @override
  String get challengeWon => 'ชนะ! 🎉';

  @override
  String get challengeLost => 'รอบนี้ยังไม่ถึงเป้า';

  @override
  String scoreLabel(int target) {
    return 'คะแนน (เป้า $target)';
  }

  @override
  String get payoutLabel => 'ได้คืน (รวมทุน)';

  @override
  String get stakeLost => 'เสียเดิมพัน';

  @override
  String get thresholdAdapts =>
      'เป้าหมายรอบต่อไปปรับตามคะแนน 20 รอบล่าสุดของคุณ ยิ่งเก่งขึ้น เป้าก็สูงขึ้น';

  @override
  String get leaveChallengeTitle => 'ออกจากชาเลนจ์?';

  @override
  String get leaveChallengeBody => 'ออกตอนนี้ถือว่ายอมแพ้ และเสียเดิมพัน';

  @override
  String get keepPlaying => 'เล่นต่อ';

  @override
  String get forfeit => 'ยอมแพ้';

  @override
  String get tierEasy => 'ง่าย';

  @override
  String get tierNormal => 'ปกติ';

  @override
  String get tierHard => 'ยาก';

  @override
  String get tierBrutal => 'โหด';

  @override
  String get chSpeed => 'สปีดรอบ';

  @override
  String get chStreak => 'ไร้ที่ติ';

  @override
  String get chWeak => 'ล่าจุดอ่อน';

  @override
  String get chWeekly => 'สัปดาห์ขยัน';

  @override
  String chSpeedRule(int n) {
    return 'ตอบถูกอย่างน้อย $n ข้อใน 60 วินาที';
  }

  @override
  String chStreakRule(int n) {
    return 'ตอบถูกติดกันอย่างน้อย $n ข้อ (ผิดครั้งแรกจบ)';
  }

  @override
  String chWeakRule(int n) {
    return 'ตอบถูกอย่างน้อย $n จาก 10 ข้อ จากคำที่อ่อน';
  }

  @override
  String chWeeklyRule(int n) {
    return 'ทบทวนให้ครบทุกใบ $n จาก 7 วัน เริ่มวันนี้';
  }

  @override
  String challengeLocked(int n) {
    return 'เรียนให้ได้ $n คำก่อนเพื่อปลดล็อก';
  }

  @override
  String challengeLockedBody(int count) {
    return 'ตอนนี้เรียนแล้ว $count คำ/ตัวอักษร';
  }

  @override
  String weeklyProgress(int done, int target, int payout) {
    return 'เคลียร์แล้ว $done/$target วัน · ชนะได้ $payout Lincoin';
  }

  @override
  String get challengeHistory => 'ประวัติชาเลนจ์';

  @override
  String historyLine(int score, int target) {
    return 'ได้ $score · เป้า $target';
  }

  @override
  String get toWin => 'เงื่อนไขชนะ';

  @override
  String get calibratingNote =>
      'ยังเล่นไม่ถึง 5 รอบ ใช้เป้าเริ่มต้นไปก่อน หลังจากนั้นเป้าจะปรับตามฝีมือคุณ';

  @override
  String stakeTooLow(int min) {
    return 'ต้องมี Lincoin พอให้เดิมพันขั้นต่ำ $min (เดิมพันได้ไม่เกิน 30% ของยอด)';
  }

  @override
  String get stake => 'เดิมพัน';

  @override
  String stakeSummary(int win, int stake, int max) {
    return 'ชนะได้ $win (รวมทุนคืน) · แพ้เสีย $stake · สูงสุด $max';
  }

  @override
  String get startChallenge => 'เริ่มชาเลนจ์';

  @override
  String get weeklyStarted =>
      'เริ่มสัปดาห์ขยันแล้ว ทบทวนให้ครบในแต่ละวันเพื่อเก็บวัน';

  @override
  String get grammarMeaning => 'ความหมาย';

  @override
  String get grammarFormation => 'วิธีใช้';

  @override
  String get grammarNotes => 'หมายเหตุ';

  @override
  String get grammarExamples => 'ตัวอย่าง';

  @override
  String get grammarCompare => 'อย่าสับสนกับ';

  @override
  String get grammarList => 'ไวยากรณ์ทั้งหมด';

  @override
  String get qCloze => 'เติมคำในช่องว่าง';

  @override
  String get newGrammar => 'ไวยากรณ์ใหม่';

  @override
  String grammarLevel(String level) {
    return 'ไวยากรณ์ $level';
  }

  @override
  String get seeAllGrammar => 'ดูทั้งหมด';

  @override
  String get deckVocabShort => 'ศัพท์';

  @override
  String get deckGrammarShort => 'ไวยากรณ์';

  @override
  String get targetRetentionGrammar => 'เป้าหมายการจำ (ไวยากรณ์)';

  @override
  String get newPerDayGrammar => 'หัวข้อไวยากรณ์ใหม่ต่อวัน';

  @override
  String get newPerDayGrammarHelp =>
      'หัวข้อละ 1 การ์ด แต่ละรอบถามด้วยประโยคตัวอย่างต่างกัน';

  @override
  String get noGrammarYet =>
      'ยังไม่มีหัวข้อที่พร้อมเรียน (ประโยคตัวอย่างกำลังแปล)';

  @override
  String get welcomeTitle => 'ยินดีต้อนรับสู่ Lincoin';

  @override
  String get welcome1 =>
      'ทบทวนทุกวันตามตารางที่คำนวณให้ จำได้นานโดยไม่ต้องท่องซ้ำเกินจำเป็น';

  @override
  String get welcome2 => 'เรียนแล้วได้ Lincoin เอาไปแลกรางวัลจริงที่คุณตั้งเอง';

  @override
  String get welcome3 =>
      'ไม่มีหัวใจ ไม่มี streak ตอบผิดก็แค่ทบทวนใหม่ ไม่มีบทลงโทษ';

  @override
  String get onbKanaTitle => 'อ่านฮิรางานะ/คาตาคานะได้หรือยัง?';

  @override
  String get onbKanaYes => 'ยังไม่ได้ เริ่มจากคานะ';

  @override
  String get onbKanaYesBody => 'เรียนตัวอักษรก่อน แล้วต่อด้วยศัพท์ N5';

  @override
  String get onbKanaNo => 'อ่านได้แล้ว ข้ามไป N5';

  @override
  String get onbKanaNoBody => 'เริ่มท่องศัพท์ N5 ได้เลย';

  @override
  String get onbPaceTitle => 'วันละเท่าไรดี?';

  @override
  String get onbPaceBody =>
      'การ์ดใหม่ทุกใบจะกลับมาให้ทบทวนอีกหลายครั้ง เลือกจำนวนที่ทำได้ทุกวันสบายๆ';

  @override
  String get paceLight => 'สบายๆ';

  @override
  String get paceNormal => 'แนะนำ';

  @override
  String get paceIntense => 'เข้มข้น';

  @override
  String cardsPerDay(int n) {
    return 'ใหม่ $n ใบ/วัน';
  }

  @override
  String paceMinutes(int m) {
    return 'ประมาณ $m นาทีต่อวันเมื่อผ่านไปสักพัก';
  }

  @override
  String get onbChangeLater => 'เปลี่ยนได้ทุกเมื่อในหน้าตั้งค่า';

  @override
  String get letsStart => 'เริ่มเลย';

  @override
  String todaySummary(int n) {
    return 'วันนี้ตอบไปแล้ว $n ข้อ';
  }

  @override
  String streakDays(int n) {
    return '$n วันติด';
  }

  @override
  String get streakHelp => 'จำนวนวันที่เรียนหรือฝึกติดต่อกัน';

  @override
  String get streakKeep => 'เรียนวันนี้เพื่อรักษาสถิติ';

  @override
  String get todayNotYet => 'วันนี้ยังไม่ได้เรียน';

  @override
  String rewardDeleted(String title) {
    return 'ลบ $title แล้ว';
  }

  @override
  String get undo => 'เลิกทำ';

  @override
  String get pressBackAgain => 'กดย้อนกลับอีกครั้งเพื่อออก';

  @override
  String grammarLevelProgress(String level, int done, int total) {
    return 'ไวยากรณ์ $level · เริ่มแล้ว $done/$total หัวข้อ';
  }
}
