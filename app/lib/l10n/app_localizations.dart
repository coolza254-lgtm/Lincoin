import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_th.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('th')];

  /// No description provided for @tabHome.
  ///
  /// In th, this message translates to:
  /// **'หน้าหลัก'**
  String get tabHome;

  /// No description provided for @tabPractice.
  ///
  /// In th, this message translates to:
  /// **'ฝึก'**
  String get tabPractice;

  /// No description provided for @tabStats.
  ///
  /// In th, this message translates to:
  /// **'สถิติ'**
  String get tabStats;

  /// No description provided for @tabShop.
  ///
  /// In th, this message translates to:
  /// **'ร้าน'**
  String get tabShop;

  /// No description provided for @settings.
  ///
  /// In th, this message translates to:
  /// **'ตั้งค่า'**
  String get settings;

  /// No description provided for @close.
  ///
  /// In th, this message translates to:
  /// **'ปิด'**
  String get close;

  /// No description provided for @cancel.
  ///
  /// In th, this message translates to:
  /// **'ยกเลิก'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In th, this message translates to:
  /// **'ยืนยัน'**
  String get confirm;

  /// No description provided for @save.
  ///
  /// In th, this message translates to:
  /// **'บันทึก'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In th, this message translates to:
  /// **'ลบ'**
  String get delete;

  /// No description provided for @send.
  ///
  /// In th, this message translates to:
  /// **'ส่ง'**
  String get send;

  /// No description provided for @next.
  ///
  /// In th, this message translates to:
  /// **'ต่อไป'**
  String get next;

  /// No description provided for @none.
  ///
  /// In th, this message translates to:
  /// **'ไม่มี'**
  String get none;

  /// No description provided for @never.
  ///
  /// In th, this message translates to:
  /// **'ยังไม่เคย'**
  String get never;

  /// No description provided for @options.
  ///
  /// In th, this message translates to:
  /// **'ตัวเลือก'**
  String get options;

  /// No description provided for @required.
  ///
  /// In th, this message translates to:
  /// **'กรุณากรอก'**
  String get required;

  /// No description provided for @invalidNumber.
  ///
  /// In th, this message translates to:
  /// **'ตัวเลขไม่ถูกต้อง'**
  String get invalidNumber;

  /// No description provided for @noContentTitle.
  ///
  /// In th, this message translates to:
  /// **'ยังไม่มีเนื้อหา'**
  String get noContentTitle;

  /// No description provided for @noContentBody.
  ///
  /// In th, this message translates to:
  /// **'แอปนี้ยังไม่มีชุดคำศัพท์ ติดตั้งได้จากหน้าอัปเดต (ออนไลน์ หรือจากไฟล์ .lincoin-content)'**
  String get noContentBody;

  /// No description provided for @goToUpdates.
  ///
  /// In th, this message translates to:
  /// **'ไปหน้าอัปเดต'**
  String get goToUpdates;

  /// No description provided for @vocabDeck.
  ///
  /// In th, this message translates to:
  /// **'ท่องศัพท์'**
  String get vocabDeck;

  /// No description provided for @grammarDeck.
  ///
  /// In th, this message translates to:
  /// **'ไวยากรณ์'**
  String get grammarDeck;

  /// No description provided for @comingInPhase.
  ///
  /// In th, this message translates to:
  /// **'เร็วๆ นี้ (เฟส {phase})'**
  String comingInPhase(int phase);

  /// No description provided for @dueLabel.
  ///
  /// In th, this message translates to:
  /// **'ต้องทบทวน'**
  String get dueLabel;

  /// No description provided for @newLabel.
  ///
  /// In th, this message translates to:
  /// **'ใหม่'**
  String get newLabel;

  /// No description provided for @minutesLabel.
  ///
  /// In th, this message translates to:
  /// **'นาที (ประมาณ)'**
  String get minutesLabel;

  /// No description provided for @newPausedBacklog.
  ///
  /// In th, this message translates to:
  /// **'พักคำใหม่ไว้ก่อน เพราะการ์ดค้างเยอะ'**
  String get newPausedBacklog;

  /// No description provided for @startStudy.
  ///
  /// In th, this message translates to:
  /// **'เริ่มเรียน'**
  String get startStudy;

  /// No description provided for @allDoneToday.
  ///
  /// In th, this message translates to:
  /// **'วันนี้ครบแล้ว 🎉'**
  String get allDoneToday;

  /// No description provided for @coverageTitle.
  ///
  /// In th, this message translates to:
  /// **'ความครอบคลุม'**
  String get coverageTitle;

  /// No description provided for @coverageHelp.
  ///
  /// In th, this message translates to:
  /// **'สัดส่วนของคำในแต่ละระดับที่น่าจะจำได้ตอนนี้ (คำนวณจากความน่าจะเป็นที่จะจำได้ของแต่ละคำ)'**
  String get coverageHelp;

  /// No description provided for @levelKana.
  ///
  /// In th, this message translates to:
  /// **'คานะ'**
  String get levelKana;

  /// No description provided for @newKana.
  ///
  /// In th, this message translates to:
  /// **'ตัวอักษรใหม่'**
  String get newKana;

  /// No description provided for @newWord.
  ///
  /// In th, this message translates to:
  /// **'คำใหม่'**
  String get newWord;

  /// No description provided for @introHint.
  ///
  /// In th, this message translates to:
  /// **'ดูให้คุ้นตา แล้วจะมีคำถามเกี่ยวกับคำนี้ในอีกไม่กี่ข้อ'**
  String get introHint;

  /// No description provided for @gotIt.
  ///
  /// In th, this message translates to:
  /// **'จำแล้ว ไปต่อ'**
  String get gotIt;

  /// No description provided for @hiragana.
  ///
  /// In th, this message translates to:
  /// **'ฮิรางานะ'**
  String get hiragana;

  /// No description provided for @katakana.
  ///
  /// In th, this message translates to:
  /// **'คาตาคานะ'**
  String get katakana;

  /// No description provided for @untranslated.
  ///
  /// In th, this message translates to:
  /// **'(ยังไม่มีคำแปลไทย แสดงต้นฉบับภาษาอังกฤษ)'**
  String get untranslated;

  /// No description provided for @moreMeanings.
  ///
  /// In th, this message translates to:
  /// **'และอีก {count} ความหมาย'**
  String moreMeanings(int count);

  /// No description provided for @exampleCredit.
  ///
  /// In th, this message translates to:
  /// **'ประโยค Tatoeba #{number} โดย {author} · {license}'**
  String exampleCredit(String number, String author, String license);

  /// No description provided for @listen.
  ///
  /// In th, this message translates to:
  /// **'ฟังเสียง'**
  String get listen;

  /// No description provided for @noJapaneseVoice.
  ///
  /// In th, this message translates to:
  /// **'เครื่องนี้ยังไม่มีเสียงภาษาญี่ปุ่น ติดตั้งได้ที่ ตั้งค่า Android → การแปลงข้อความเป็นเสียง'**
  String get noJapaneseVoice;

  /// No description provided for @qMeaning.
  ///
  /// In th, this message translates to:
  /// **'ความหมายคืออะไร'**
  String get qMeaning;

  /// No description provided for @qTypeReading.
  ///
  /// In th, this message translates to:
  /// **'พิมพ์คำอ่าน'**
  String get qTypeReading;

  /// No description provided for @qTypeRomaji.
  ///
  /// In th, this message translates to:
  /// **'พิมพ์โรมาจิ'**
  String get qTypeRomaji;

  /// No description provided for @kanaPreview.
  ///
  /// In th, this message translates to:
  /// **'คานะที่พิมพ์'**
  String get kanaPreview;

  /// No description provided for @hintStartsWith.
  ///
  /// In th, this message translates to:
  /// **'ขึ้นต้นด้วย {kana}'**
  String hintStartsWith(String kana);

  /// No description provided for @synonymTryAgain.
  ///
  /// In th, this message translates to:
  /// **'คำนี้ความหมายเดียวกัน แต่เราต้องการอีกคำ ลองอีกครั้ง'**
  String get synonymTryAgain;

  /// No description provided for @checkAnswer.
  ///
  /// In th, this message translates to:
  /// **'ตรวจคำตอบ'**
  String get checkAnswer;

  /// No description provided for @guessing.
  ///
  /// In th, this message translates to:
  /// **'ตอบแบบเดา'**
  String get guessing;

  /// No description provided for @guessingHelp.
  ///
  /// In th, this message translates to:
  /// **'เลือกไว้ถ้าไม่แน่ใจ การ์ดจะกลับมาเร็วขึ้น และไม่นับว่าจำได้'**
  String get guessingHelp;

  /// No description provided for @hint.
  ///
  /// In th, this message translates to:
  /// **'คำใบ้'**
  String get hint;

  /// No description provided for @dontKnow.
  ///
  /// In th, this message translates to:
  /// **'ไม่รู้'**
  String get dontKnow;

  /// No description provided for @correct.
  ///
  /// In th, this message translates to:
  /// **'ถูกต้อง'**
  String get correct;

  /// No description provided for @notYet.
  ///
  /// In th, this message translates to:
  /// **'ยังไม่ถูก'**
  String get notYet;

  /// No description provided for @yourAnswer.
  ///
  /// In th, this message translates to:
  /// **'คำตอบของคุณ: {answer}'**
  String yourAnswer(String answer);

  /// No description provided for @willReviewSoon.
  ///
  /// In th, this message translates to:
  /// **'ไม่เป็นไร คำนี้จะกลับมาให้ทบทวนเร็วๆ นี้'**
  String get willReviewSoon;

  /// No description provided for @graduated.
  ///
  /// In th, this message translates to:
  /// **'จำคำนี้ได้แล้ว จะเว้นช่วงทบทวนให้นานขึ้น'**
  String get graduated;

  /// No description provided for @masteredNow.
  ///
  /// In th, this message translates to:
  /// **'คำนี้อยู่ในระดับเชี่ยวชาญแล้ว'**
  String get masteredNow;

  /// No description provided for @leechNote.
  ///
  /// In th, this message translates to:
  /// **'คำนี้ลืมบ่อย ลองดูประโยคตัวอย่างหรือจำวิธีอื่นดู'**
  String get leechNote;

  /// No description provided for @reportTranslation.
  ///
  /// In th, this message translates to:
  /// **'รายงานคำแปล'**
  String get reportTranslation;

  /// No description provided for @reportHint.
  ///
  /// In th, this message translates to:
  /// **'คำแปลผิดอย่างไร หรือควรเป็นอะไร (ไม่บังคับ)'**
  String get reportHint;

  /// No description provided for @reportSaved.
  ///
  /// In th, this message translates to:
  /// **'บันทึกแล้ว ขอบคุณครับ'**
  String get reportSaved;

  /// No description provided for @nothingToStudy.
  ///
  /// In th, this message translates to:
  /// **'ไม่มีการ์ดให้เรียนตอนนี้'**
  String get nothingToStudy;

  /// No description provided for @sessionDone.
  ///
  /// In th, this message translates to:
  /// **'จบรอบนี้แล้ว'**
  String get sessionDone;

  /// No description provided for @answeredLabel.
  ///
  /// In th, this message translates to:
  /// **'ข้อ'**
  String get answeredLabel;

  /// No description provided for @accuracyLabel.
  ///
  /// In th, this message translates to:
  /// **'ถูก'**
  String get accuracyLabel;

  /// No description provided for @coinsEarned.
  ///
  /// In th, this message translates to:
  /// **'ได้ Lincoin'**
  String get coinsEarned;

  /// No description provided for @bonusDailyClear.
  ///
  /// In th, this message translates to:
  /// **'โบนัสเคลียร์การ์ดวันนี้'**
  String get bonusDailyClear;

  /// No description provided for @bonusCoverage.
  ///
  /// In th, this message translates to:
  /// **'โบนัสความครอบคลุม'**
  String get bonusCoverage;

  /// No description provided for @laterSteps.
  ///
  /// In th, this message translates to:
  /// **'มีการ์ดที่กำลังเรียนอีก {count} ใบ จะกลับมาให้ทบทวนภายหลังวันนี้'**
  String laterSteps(int count);

  /// No description provided for @backHome.
  ///
  /// In th, this message translates to:
  /// **'กลับหน้าหลัก'**
  String get backHome;

  /// No description provided for @sectionStudy.
  ///
  /// In th, this message translates to:
  /// **'การเรียน'**
  String get sectionStudy;

  /// No description provided for @sectionLook.
  ///
  /// In th, this message translates to:
  /// **'หน้าตา'**
  String get sectionLook;

  /// No description provided for @sectionApp.
  ///
  /// In th, this message translates to:
  /// **'แอป'**
  String get sectionApp;

  /// No description provided for @targetRetention.
  ///
  /// In th, this message translates to:
  /// **'เป้าหมายการจำ'**
  String get targetRetention;

  /// No description provided for @targetRetentionHelp.
  ///
  /// In th, this message translates to:
  /// **'โอกาสจำได้ตอนถึงรอบทบทวน สูงขึ้น = ทบทวนบ่อยขึ้นมาก (90% เหมาะกับส่วนใหญ่)'**
  String get targetRetentionHelp;

  /// No description provided for @newPerDay.
  ///
  /// In th, this message translates to:
  /// **'การ์ดใหม่ต่อวัน'**
  String get newPerDay;

  /// No description provided for @newPerDayHelp.
  ///
  /// In th, this message translates to:
  /// **'1 คำมี 2 การ์ด (ความหมาย และคำอ่าน) การ์ดใหม่ทำให้งานทบทวนในอนาคตเพิ่มขึ้น'**
  String get newPerDayHelp;

  /// No description provided for @includeKana.
  ///
  /// In th, this message translates to:
  /// **'เริ่มจากคานะ'**
  String get includeKana;

  /// No description provided for @includeKanaHelp.
  ///
  /// In th, this message translates to:
  /// **'ปิดถ้าอ่านฮิรางานะ/คาตาคานะได้แล้ว'**
  String get includeKanaHelp;

  /// No description provided for @furiganaMode.
  ///
  /// In th, this message translates to:
  /// **'ฟุริงานะ'**
  String get furiganaMode;

  /// No description provided for @furiganaAlways.
  ///
  /// In th, this message translates to:
  /// **'แสดงเสมอ'**
  String get furiganaAlways;

  /// No description provided for @furiganaHideMastered.
  ///
  /// In th, this message translates to:
  /// **'ซ่อนคำที่เชี่ยวชาญแล้ว'**
  String get furiganaHideMastered;

  /// No description provided for @furiganaNever.
  ///
  /// In th, this message translates to:
  /// **'ซ่อนทั้งหมด'**
  String get furiganaNever;

  /// No description provided for @dayStart.
  ///
  /// In th, this message translates to:
  /// **'เริ่มวันใหม่เวลา'**
  String get dayStart;

  /// No description provided for @dayStartHelp.
  ///
  /// In th, this message translates to:
  /// **'เรียนหลังเที่ยงคืนก่อน 0{hour}:00 ยังนับเป็นวันก่อนหน้า'**
  String dayStartHelp(int hour);

  /// No description provided for @theme.
  ///
  /// In th, this message translates to:
  /// **'ธีม'**
  String get theme;

  /// No description provided for @updates.
  ///
  /// In th, this message translates to:
  /// **'อัปเดต'**
  String get updates;

  /// No description provided for @backup.
  ///
  /// In th, this message translates to:
  /// **'สำรองข้อมูล'**
  String get backup;

  /// No description provided for @credits.
  ///
  /// In th, this message translates to:
  /// **'เครดิตและสัญญาอนุญาต'**
  String get credits;

  /// No description provided for @appVersion.
  ///
  /// In th, this message translates to:
  /// **'เวอร์ชันแอป'**
  String get appVersion;

  /// No description provided for @contentVersion.
  ///
  /// In th, this message translates to:
  /// **'เวอร์ชันเนื้อหา'**
  String get contentVersion;

  /// No description provided for @lastChecked.
  ///
  /// In th, this message translates to:
  /// **'ตรวจล่าสุด'**
  String get lastChecked;

  /// No description provided for @checkForUpdates.
  ///
  /// In th, this message translates to:
  /// **'ตรวจหาอัปเดต'**
  String get checkForUpdates;

  /// No description provided for @updateFromFile.
  ///
  /// In th, this message translates to:
  /// **'อัปเดตจากไฟล์'**
  String get updateFromFile;

  /// No description provided for @updateFromFileHelp.
  ///
  /// In th, this message translates to:
  /// **'เลือกไฟล์ .apk (แอป) หรือ .lincoin-content (เนื้อหา) ที่อยู่ในเครื่องแล้ว ไม่ต้องใช้เน็ต'**
  String get updateFromFileHelp;

  /// No description provided for @upToDate.
  ///
  /// In th, this message translates to:
  /// **'เป็นเวอร์ชันล่าสุดแล้ว'**
  String get upToDate;

  /// No description provided for @newAppVersion.
  ///
  /// In th, this message translates to:
  /// **'แอปเวอร์ชันใหม่ {version}'**
  String newAppVersion(String version);

  /// No description provided for @newContentVersion.
  ///
  /// In th, this message translates to:
  /// **'เนื้อหาเวอร์ชันใหม่ {version}'**
  String newContentVersion(String version);

  /// No description provided for @updateApp.
  ///
  /// In th, this message translates to:
  /// **'อัปเดตแอป'**
  String get updateApp;

  /// No description provided for @updateContent.
  ///
  /// In th, this message translates to:
  /// **'อัปเดตเนื้อหา'**
  String get updateContent;

  /// No description provided for @contentNeedsNewerApp.
  ///
  /// In th, this message translates to:
  /// **'มีเนื้อหาใหม่ที่ต้องใช้แอปเวอร์ชันใหม่กว่า อัปเดตแอปก่อน'**
  String get contentNeedsNewerApp;

  /// No description provided for @onlineCheck.
  ///
  /// In th, this message translates to:
  /// **'ตรวจอัปเดตออนไลน์'**
  String get onlineCheck;

  /// No description provided for @onlineCheckHelp.
  ///
  /// In th, this message translates to:
  /// **'ปิดแล้วแอปจะไม่ใช้เน็ตเพื่ออัปเดตเลย (ยังอัปเดตจากไฟล์ได้)'**
  String get onlineCheckHelp;

  /// No description provided for @rollbackContent.
  ///
  /// In th, this message translates to:
  /// **'ย้อนกลับเป็นเนื้อหา {version}'**
  String rollbackContent(String version);

  /// No description provided for @rollbackHelp.
  ///
  /// In th, this message translates to:
  /// **'ความก้าวหน้าไม่หาย การ์ดของคำที่ไม่มีในเวอร์ชันนั้นจะถูกพักไว้'**
  String get rollbackHelp;

  /// No description provided for @updateSafety.
  ///
  /// In th, this message translates to:
  /// **'ก่อนอัปเดตทุกครั้งแอปจะสำรองข้อมูลการเรียนอัตโนมัติ ทุกไฟล์ตรวจด้วย sha256 และไม่มีการติดตั้งโดยไม่กดยืนยัน'**
  String get updateSafety;

  /// No description provided for @installAppFromFile.
  ///
  /// In th, this message translates to:
  /// **'ติดตั้งแอปเวอร์ชัน {version}?'**
  String installAppFromFile(String version);

  /// No description provided for @installAppFromFileHelp.
  ///
  /// In th, this message translates to:
  /// **'แอปจะสำรองข้อมูลก่อน แล้วเปิดตัวติดตั้งของ Android (ไฟล์ต้องเซ็นด้วยกุญแจเดียวกับแอปที่ติดตั้งอยู่)'**
  String get installAppFromFileHelp;

  /// No description provided for @installContentFromFile.
  ///
  /// In th, this message translates to:
  /// **'ติดตั้งเนื้อหาเวอร์ชัน {version}?'**
  String installContentFromFile(String version);

  /// No description provided for @installedContent.
  ///
  /// In th, this message translates to:
  /// **'ที่ติดตั้งอยู่: {version}'**
  String installedContent(String version);

  /// No description provided for @backupHelp.
  ///
  /// In th, this message translates to:
  /// **'ข้อมูลการเรียน Lincoin และรางวัลทั้งหมดอยู่ในไฟล์เดียว ส่งออกเก็บไว้ใน Drive หรือเครื่องอื่นได้ แอปสำรองให้อัตโนมัติก่อนอัปเดตทุกครั้ง'**
  String get backupHelp;

  /// No description provided for @exportBackup.
  ///
  /// In th, this message translates to:
  /// **'ส่งออกไฟล์สำรอง'**
  String get exportBackup;

  /// No description provided for @importBackup.
  ///
  /// In th, this message translates to:
  /// **'นำเข้าไฟล์สำรอง'**
  String get importBackup;

  /// No description provided for @exported.
  ///
  /// In th, this message translates to:
  /// **'บันทึกไฟล์สำรองแล้ว'**
  String get exported;

  /// No description provided for @exportCancelled.
  ///
  /// In th, this message translates to:
  /// **'ยกเลิกการบันทึก'**
  String get exportCancelled;

  /// No description provided for @autoBackups.
  ///
  /// In th, this message translates to:
  /// **'สำรองในเครื่อง (5 ชุดล่าสุด)'**
  String get autoBackups;

  /// No description provided for @noBackups.
  ///
  /// In th, this message translates to:
  /// **'ยังไม่มี'**
  String get noBackups;

  /// No description provided for @restore.
  ///
  /// In th, this message translates to:
  /// **'กู้คืน'**
  String get restore;

  /// No description provided for @restoreConfirmTitle.
  ///
  /// In th, this message translates to:
  /// **'กู้คืนข้อมูลจากไฟล์นี้?'**
  String get restoreConfirmTitle;

  /// No description provided for @restoreConfirmBody.
  ///
  /// In th, this message translates to:
  /// **'ข้อมูลปัจจุบันจะถูกแทนที่ (แอปจะสำรองข้อมูลปัจจุบันไว้ก่อน ย้อนกลับได้)'**
  String get restoreConfirmBody;

  /// No description provided for @restored.
  ///
  /// In th, this message translates to:
  /// **'กู้คืนแล้ว'**
  String get restored;

  /// No description provided for @reasonBeforeUpdate.
  ///
  /// In th, this message translates to:
  /// **'ก่อนอัปเดตแอป'**
  String get reasonBeforeUpdate;

  /// No description provided for @reasonBeforeContent.
  ///
  /// In th, this message translates to:
  /// **'ก่อนอัปเดตเนื้อหา'**
  String get reasonBeforeContent;

  /// No description provided for @reasonBeforeMigrate.
  ///
  /// In th, this message translates to:
  /// **'ก่อนปรับฐานข้อมูล'**
  String get reasonBeforeMigrate;

  /// No description provided for @reasonBeforeRestore.
  ///
  /// In th, this message translates to:
  /// **'ก่อนกู้คืน'**
  String get reasonBeforeRestore;

  /// No description provided for @reasonManual.
  ///
  /// In th, this message translates to:
  /// **'สำรองเอง'**
  String get reasonManual;

  /// No description provided for @versionLine.
  ///
  /// In th, this message translates to:
  /// **'แอป {app} · เนื้อหา {content}'**
  String versionLine(String app, String content);

  /// No description provided for @contentSources.
  ///
  /// In th, this message translates to:
  /// **'แหล่งเนื้อหา'**
  String get contentSources;

  /// No description provided for @contentLicenseNote.
  ///
  /// In th, this message translates to:
  /// **'เนื้อหาในแอป (รวมคำแปลไทยที่ดัดแปลงจาก JMdict) เผยแพร่ภายใต้ CC BY-SA 4.0 ประโยคตัวอย่างจาก Tatoeba แสดงชื่อผู้เขียนทุกประโยค'**
  String get contentLicenseNote;

  /// No description provided for @fonts.
  ///
  /// In th, this message translates to:
  /// **'ฟอนต์'**
  String get fonts;

  /// No description provided for @softwareLicenses.
  ///
  /// In th, this message translates to:
  /// **'สัญญาอนุญาตซอฟต์แวร์'**
  String get softwareLicenses;

  /// No description provided for @expectedKnown.
  ///
  /// In th, this message translates to:
  /// **'คำที่น่าจะจำได้ตอนนี้'**
  String get expectedKnown;

  /// No description provided for @expectedKnownHelp.
  ///
  /// In th, this message translates to:
  /// **'ผลรวมความน่าจะเป็นที่จะจำได้ของทุกคำ ไม่ใช่แค่จำนวนคำที่เคยเห็น'**
  String get expectedKnownHelp;

  /// No description provided for @itemsStarted.
  ///
  /// In th, this message translates to:
  /// **'เริ่มเรียนแล้ว'**
  String get itemsStarted;

  /// No description provided for @masteredItems.
  ///
  /// In th, this message translates to:
  /// **'เชี่ยวชาญ'**
  String get masteredItems;

  /// No description provided for @minutes7Days.
  ///
  /// In th, this message translates to:
  /// **'นาที (7 วัน)'**
  String get minutes7Days;

  /// No description provided for @retentionTitle.
  ///
  /// In th, this message translates to:
  /// **'การจำจริง (30 วัน)'**
  String get retentionTitle;

  /// No description provided for @targetIs.
  ///
  /// In th, this message translates to:
  /// **'เป้าหมาย {percent}%'**
  String targetIs(int percent);

  /// No description provided for @retentionHelp.
  ///
  /// In th, this message translates to:
  /// **'สัดส่วนที่ตอบถูกเมื่อถึงรอบทบทวน จาก {n} ครั้ง ถ้าใกล้เป้าหมาย แปลว่าตารางทบทวนแม่นยำ'**
  String retentionHelp(int n);

  /// No description provided for @smallSample.
  ///
  /// In th, this message translates to:
  /// **'ข้อมูลยังน้อย ตัวเลขอาจแกว่ง'**
  String get smallSample;

  /// No description provided for @levelLine.
  ///
  /// In th, this message translates to:
  /// **'จำได้ ~{known}/{total} · เชี่ยวชาญ {mastered}'**
  String levelLine(String known, int total, int mastered);

  /// No description provided for @activity14.
  ///
  /// In th, this message translates to:
  /// **'การทบทวน 14 วันล่าสุด'**
  String get activity14;

  /// No description provided for @activityHelp.
  ///
  /// In th, this message translates to:
  /// **'แท่งเข้ม = ตอบถูก แท่งอ่อน = ทั้งหมด'**
  String get activityHelp;

  /// No description provided for @forecast7.
  ///
  /// In th, this message translates to:
  /// **'การ์ดที่จะถึงรอบ 7 วันข้างหน้า'**
  String get forecast7;

  /// No description provided for @forecastHelp.
  ///
  /// In th, this message translates to:
  /// **'รวมการ์ดค้างไว้ในวันนี้'**
  String get forecastHelp;

  /// No description provided for @today.
  ///
  /// In th, this message translates to:
  /// **'วันนี้'**
  String get today;

  /// No description provided for @calibration.
  ///
  /// In th, this message translates to:
  /// **'ความแม่นของการคาดการณ์'**
  String get calibration;

  /// No description provided for @calibrationHelp.
  ///
  /// In th, this message translates to:
  /// **'เทียบโอกาสจำที่ระบบคาด (แถว) กับที่จำได้จริง (แถบ) ค่า log loss {logLoss} ยิ่งต่ำยิ่งดี'**
  String calibrationHelp(String logLoss);

  /// No description provided for @leeches.
  ///
  /// In th, this message translates to:
  /// **'คำที่ลืมบ่อย {count} คำ'**
  String leeches(int count);

  /// No description provided for @totalReviews.
  ///
  /// In th, this message translates to:
  /// **'ทบทวนไปแล้วทั้งหมด {count} ครั้ง'**
  String totalReviews(int count);

  /// No description provided for @balance.
  ///
  /// In th, this message translates to:
  /// **'ยอด Lincoin'**
  String get balance;

  /// No description provided for @avgPerDay.
  ///
  /// In th, this message translates to:
  /// **'ได้เฉลี่ย/วัน (7 วัน)'**
  String get avgPerDay;

  /// No description provided for @noRewardsTitle.
  ///
  /// In th, this message translates to:
  /// **'ยังไม่มีรางวัล'**
  String get noRewardsTitle;

  /// No description provided for @noRewardsBody.
  ///
  /// In th, this message translates to:
  /// **'ตั้งรางวัลให้ตัวเอง เช่น ชานม 1 แก้ว ดูหนัง 1 เรื่อง แล้วใช้ Lincoin แลก'**
  String get noRewardsBody;

  /// No description provided for @addReward.
  ///
  /// In th, this message translates to:
  /// **'เพิ่มรางวัล'**
  String get addReward;

  /// No description provided for @editReward.
  ///
  /// In th, this message translates to:
  /// **'แก้ไขรางวัล'**
  String get editReward;

  /// No description provided for @emoji.
  ///
  /// In th, this message translates to:
  /// **'ไอคอน'**
  String get emoji;

  /// No description provided for @rewardTitle.
  ///
  /// In th, this message translates to:
  /// **'ชื่อรางวัล'**
  String get rewardTitle;

  /// No description provided for @price.
  ///
  /// In th, this message translates to:
  /// **'ราคา (Lincoin)'**
  String get price;

  /// No description provided for @priceHelp.
  ///
  /// In th, this message translates to:
  /// **'ทบทวนครบทุกวันได้ราว 50–150 Lincoin/วัน'**
  String get priceHelp;

  /// No description provided for @repeatable.
  ///
  /// In th, this message translates to:
  /// **'แลกได้หลายครั้ง'**
  String get repeatable;

  /// No description provided for @cooldownDays.
  ///
  /// In th, this message translates to:
  /// **'เว้นระยะกี่วันต่อครั้ง (ไม่บังคับ)'**
  String get cooldownDays;

  /// No description provided for @oneTime.
  ///
  /// In th, this message translates to:
  /// **'ครั้งเดียว'**
  String get oneTime;

  /// No description provided for @everyNDays.
  ///
  /// In th, this message translates to:
  /// **'ทุก {days} วัน'**
  String everyNDays(int days);

  /// No description provided for @readyToRedeem.
  ///
  /// In th, this message translates to:
  /// **'แลกได้แล้ว!'**
  String get readyToRedeem;

  /// No description provided for @needMore.
  ///
  /// In th, this message translates to:
  /// **'อีก {amount} Lincoin'**
  String needMore(int amount);

  /// No description provided for @cooldownUntil.
  ///
  /// In th, this message translates to:
  /// **'แลกได้อีกครั้ง {date}'**
  String cooldownUntil(String date);

  /// No description provided for @alreadyRedeemed.
  ///
  /// In th, this message translates to:
  /// **'แลกไปแล้ว'**
  String get alreadyRedeemed;

  /// No description provided for @redeem.
  ///
  /// In th, this message translates to:
  /// **'แลก'**
  String get redeem;

  /// No description provided for @redeemConfirm.
  ///
  /// In th, this message translates to:
  /// **'ใช้ {price} Lincoin แลกรางวัลนี้?'**
  String redeemConfirm(int price);

  /// No description provided for @redeemed.
  ///
  /// In th, this message translates to:
  /// **'แลก {title} แล้ว ขอให้สนุก!'**
  String redeemed(String title);

  /// No description provided for @redeemHistory.
  ///
  /// In th, this message translates to:
  /// **'ประวัติการแลก'**
  String get redeemHistory;

  /// No description provided for @practiceTitle.
  ///
  /// In th, this message translates to:
  /// **'ฝึก'**
  String get practiceTitle;

  /// No description provided for @practiceBody.
  ///
  /// In th, this message translates to:
  /// **'เล่นได้ไม่จำกัดจากคำที่เรียนแล้ว รอบละ 10 ข้อ ไม่กระทบตารางทบทวน ได้ Lincoin แบบลดหลั่นต่อวัน'**
  String get practiceBody;

  /// No description provided for @challengeTitle.
  ///
  /// In th, this message translates to:
  /// **'ท้าทาย'**
  String get challengeTitle;

  /// No description provided for @challengeBody.
  ///
  /// In th, this message translates to:
  /// **'เดิมพัน Lincoin กับเป้าหมายที่ปรับตามฝีมือคุณเอง ชนะได้คืนทุนพร้อมกำไร แพ้เสียเดิมพัน ออกกลางคันถือว่าแพ้'**
  String get challengeBody;

  /// No description provided for @qChooseWord.
  ///
  /// In th, this message translates to:
  /// **'เลือกคำภาษาญี่ปุ่น'**
  String get qChooseWord;

  /// No description provided for @qChooseRomaji.
  ///
  /// In th, this message translates to:
  /// **'อ่านว่าอะไร'**
  String get qChooseRomaji;

  /// No description provided for @learnedItems.
  ///
  /// In th, this message translates to:
  /// **'เรียนแล้ว'**
  String get learnedItems;

  /// No description provided for @weakItems.
  ///
  /// In th, this message translates to:
  /// **'จุดอ่อน'**
  String get weakItems;

  /// No description provided for @recentItems.
  ///
  /// In th, this message translates to:
  /// **'ใหม่ (7 วัน)'**
  String get recentItems;

  /// No description provided for @practiceRate.
  ///
  /// In th, this message translates to:
  /// **'ได้จากการฝึกวันนี้ · อัตราตอนนี้ {percent}%'**
  String practiceRate(int percent);

  /// No description provided for @startPractice.
  ///
  /// In th, this message translates to:
  /// **'เริ่มฝึก 10 ข้อ'**
  String get startPractice;

  /// No description provided for @practiceNeedsItems.
  ///
  /// In th, this message translates to:
  /// **'เรียนอย่างน้อย 4 คำก่อน แล้วค่อยมาฝึก'**
  String get practiceNeedsItems;

  /// No description provided for @practiceDone.
  ///
  /// In th, this message translates to:
  /// **'จบรอบฝึกแล้ว'**
  String get practiceDone;

  /// No description provided for @correctCount.
  ///
  /// In th, this message translates to:
  /// **'ตอบถูก'**
  String get correctCount;

  /// No description provided for @bestCombo.
  ///
  /// In th, this message translates to:
  /// **'คอมโบสูงสุด'**
  String get bestCombo;

  /// No description provided for @combo.
  ///
  /// In th, this message translates to:
  /// **'คอมโบ {n}'**
  String combo(int n);

  /// No description provided for @done.
  ///
  /// In th, this message translates to:
  /// **'เสร็จ'**
  String get done;

  /// No description provided for @challengeWon.
  ///
  /// In th, this message translates to:
  /// **'ชนะ! 🎉'**
  String get challengeWon;

  /// No description provided for @challengeLost.
  ///
  /// In th, this message translates to:
  /// **'รอบนี้ยังไม่ถึงเป้า'**
  String get challengeLost;

  /// No description provided for @scoreLabel.
  ///
  /// In th, this message translates to:
  /// **'คะแนน (เป้า {target})'**
  String scoreLabel(int target);

  /// No description provided for @payoutLabel.
  ///
  /// In th, this message translates to:
  /// **'ได้คืน (รวมทุน)'**
  String get payoutLabel;

  /// No description provided for @stakeLost.
  ///
  /// In th, this message translates to:
  /// **'เสียเดิมพัน'**
  String get stakeLost;

  /// No description provided for @thresholdAdapts.
  ///
  /// In th, this message translates to:
  /// **'เป้าหมายรอบต่อไปปรับตามคะแนน 20 รอบล่าสุดของคุณ ยิ่งเก่งขึ้น เป้าก็สูงขึ้น'**
  String get thresholdAdapts;

  /// No description provided for @leaveChallengeTitle.
  ///
  /// In th, this message translates to:
  /// **'ออกจากชาเลนจ์?'**
  String get leaveChallengeTitle;

  /// No description provided for @leaveChallengeBody.
  ///
  /// In th, this message translates to:
  /// **'ออกตอนนี้ถือว่ายอมแพ้ และเสียเดิมพัน'**
  String get leaveChallengeBody;

  /// No description provided for @keepPlaying.
  ///
  /// In th, this message translates to:
  /// **'เล่นต่อ'**
  String get keepPlaying;

  /// No description provided for @forfeit.
  ///
  /// In th, this message translates to:
  /// **'ยอมแพ้'**
  String get forfeit;

  /// No description provided for @tierEasy.
  ///
  /// In th, this message translates to:
  /// **'ง่าย'**
  String get tierEasy;

  /// No description provided for @tierNormal.
  ///
  /// In th, this message translates to:
  /// **'ปกติ'**
  String get tierNormal;

  /// No description provided for @tierHard.
  ///
  /// In th, this message translates to:
  /// **'ยาก'**
  String get tierHard;

  /// No description provided for @tierBrutal.
  ///
  /// In th, this message translates to:
  /// **'โหด'**
  String get tierBrutal;

  /// No description provided for @chSpeed.
  ///
  /// In th, this message translates to:
  /// **'สปีดรอบ'**
  String get chSpeed;

  /// No description provided for @chStreak.
  ///
  /// In th, this message translates to:
  /// **'ไร้ที่ติ'**
  String get chStreak;

  /// No description provided for @chWeak.
  ///
  /// In th, this message translates to:
  /// **'ล่าจุดอ่อน'**
  String get chWeak;

  /// No description provided for @chWeekly.
  ///
  /// In th, this message translates to:
  /// **'สัปดาห์ขยัน'**
  String get chWeekly;

  /// No description provided for @chSpeedRule.
  ///
  /// In th, this message translates to:
  /// **'ตอบถูกอย่างน้อย {n} ข้อใน 60 วินาที'**
  String chSpeedRule(int n);

  /// No description provided for @chStreakRule.
  ///
  /// In th, this message translates to:
  /// **'ตอบถูกติดกันอย่างน้อย {n} ข้อ (ผิดครั้งแรกจบ)'**
  String chStreakRule(int n);

  /// No description provided for @chWeakRule.
  ///
  /// In th, this message translates to:
  /// **'ตอบถูกอย่างน้อย {n} จาก 10 ข้อ จากคำที่อ่อน'**
  String chWeakRule(int n);

  /// No description provided for @chWeeklyRule.
  ///
  /// In th, this message translates to:
  /// **'ทบทวนให้ครบทุกใบ {n} จาก 7 วัน เริ่มวันนี้'**
  String chWeeklyRule(int n);

  /// No description provided for @challengeLocked.
  ///
  /// In th, this message translates to:
  /// **'เรียนให้ได้ {n} คำก่อนเพื่อปลดล็อก'**
  String challengeLocked(int n);

  /// No description provided for @challengeLockedBody.
  ///
  /// In th, this message translates to:
  /// **'ตอนนี้เรียนแล้ว {count} คำ/ตัวอักษร'**
  String challengeLockedBody(int count);

  /// No description provided for @weeklyProgress.
  ///
  /// In th, this message translates to:
  /// **'เคลียร์แล้ว {done}/{target} วัน · ชนะได้ {payout} Lincoin'**
  String weeklyProgress(int done, int target, int payout);

  /// No description provided for @challengeHistory.
  ///
  /// In th, this message translates to:
  /// **'ประวัติชาเลนจ์'**
  String get challengeHistory;

  /// No description provided for @historyLine.
  ///
  /// In th, this message translates to:
  /// **'ได้ {score} · เป้า {target}'**
  String historyLine(int score, int target);

  /// No description provided for @toWin.
  ///
  /// In th, this message translates to:
  /// **'เงื่อนไขชนะ'**
  String get toWin;

  /// No description provided for @calibratingNote.
  ///
  /// In th, this message translates to:
  /// **'ยังเล่นไม่ถึง 5 รอบ ใช้เป้าเริ่มต้นไปก่อน หลังจากนั้นเป้าจะปรับตามฝีมือคุณ'**
  String get calibratingNote;

  /// No description provided for @stakeTooLow.
  ///
  /// In th, this message translates to:
  /// **'ต้องมี Lincoin พอให้เดิมพันขั้นต่ำ {min} (เดิมพันได้ไม่เกิน 30% ของยอด)'**
  String stakeTooLow(int min);

  /// No description provided for @stake.
  ///
  /// In th, this message translates to:
  /// **'เดิมพัน'**
  String get stake;

  /// No description provided for @stakeSummary.
  ///
  /// In th, this message translates to:
  /// **'ชนะได้ {win} (รวมทุนคืน) · แพ้เสีย {stake} · สูงสุด {max}'**
  String stakeSummary(int win, int stake, int max);

  /// No description provided for @startChallenge.
  ///
  /// In th, this message translates to:
  /// **'เริ่มชาเลนจ์'**
  String get startChallenge;

  /// No description provided for @weeklyStarted.
  ///
  /// In th, this message translates to:
  /// **'เริ่มสัปดาห์ขยันแล้ว ทบทวนให้ครบในแต่ละวันเพื่อเก็บวัน'**
  String get weeklyStarted;

  /// No description provided for @grammarMeaning.
  ///
  /// In th, this message translates to:
  /// **'ความหมาย'**
  String get grammarMeaning;

  /// No description provided for @grammarFormation.
  ///
  /// In th, this message translates to:
  /// **'วิธีใช้'**
  String get grammarFormation;

  /// No description provided for @grammarNotes.
  ///
  /// In th, this message translates to:
  /// **'หมายเหตุ'**
  String get grammarNotes;

  /// No description provided for @grammarExamples.
  ///
  /// In th, this message translates to:
  /// **'ตัวอย่าง'**
  String get grammarExamples;

  /// No description provided for @grammarCompare.
  ///
  /// In th, this message translates to:
  /// **'อย่าสับสนกับ'**
  String get grammarCompare;

  /// No description provided for @grammarList.
  ///
  /// In th, this message translates to:
  /// **'ไวยากรณ์ทั้งหมด'**
  String get grammarList;

  /// No description provided for @qCloze.
  ///
  /// In th, this message translates to:
  /// **'เติมคำในช่องว่าง'**
  String get qCloze;

  /// No description provided for @newGrammar.
  ///
  /// In th, this message translates to:
  /// **'ไวยากรณ์ใหม่'**
  String get newGrammar;

  /// No description provided for @grammarLevel.
  ///
  /// In th, this message translates to:
  /// **'ไวยากรณ์ {level}'**
  String grammarLevel(String level);

  /// No description provided for @seeAllGrammar.
  ///
  /// In th, this message translates to:
  /// **'ดูทั้งหมด'**
  String get seeAllGrammar;

  /// No description provided for @deckVocabShort.
  ///
  /// In th, this message translates to:
  /// **'ศัพท์'**
  String get deckVocabShort;

  /// No description provided for @deckGrammarShort.
  ///
  /// In th, this message translates to:
  /// **'ไวยากรณ์'**
  String get deckGrammarShort;

  /// No description provided for @targetRetentionGrammar.
  ///
  /// In th, this message translates to:
  /// **'เป้าหมายการจำ (ไวยากรณ์)'**
  String get targetRetentionGrammar;

  /// No description provided for @newPerDayGrammar.
  ///
  /// In th, this message translates to:
  /// **'หัวข้อไวยากรณ์ใหม่ต่อวัน'**
  String get newPerDayGrammar;

  /// No description provided for @newPerDayGrammarHelp.
  ///
  /// In th, this message translates to:
  /// **'หัวข้อละ 1 การ์ด แต่ละรอบถามด้วยประโยคตัวอย่างต่างกัน'**
  String get newPerDayGrammarHelp;

  /// No description provided for @noGrammarYet.
  ///
  /// In th, this message translates to:
  /// **'ยังไม่มีหัวข้อที่พร้อมเรียน (ประโยคตัวอย่างกำลังแปล)'**
  String get noGrammarYet;

  /// No description provided for @welcomeTitle.
  ///
  /// In th, this message translates to:
  /// **'ยินดีต้อนรับสู่ Lincoin'**
  String get welcomeTitle;

  /// No description provided for @welcome1.
  ///
  /// In th, this message translates to:
  /// **'ทบทวนทุกวันตามตารางที่คำนวณให้ จำได้นานโดยไม่ต้องท่องซ้ำเกินจำเป็น'**
  String get welcome1;

  /// No description provided for @welcome2.
  ///
  /// In th, this message translates to:
  /// **'เรียนแล้วได้ Lincoin เอาไปแลกรางวัลจริงที่คุณตั้งเอง'**
  String get welcome2;

  /// No description provided for @welcome3.
  ///
  /// In th, this message translates to:
  /// **'ไม่มีหัวใจ ไม่มี streak ตอบผิดก็แค่ทบทวนใหม่ ไม่มีบทลงโทษ'**
  String get welcome3;

  /// No description provided for @onbKanaTitle.
  ///
  /// In th, this message translates to:
  /// **'อ่านฮิรางานะ/คาตาคานะได้หรือยัง?'**
  String get onbKanaTitle;

  /// No description provided for @onbKanaYes.
  ///
  /// In th, this message translates to:
  /// **'ยังไม่ได้ เริ่มจากคานะ'**
  String get onbKanaYes;

  /// No description provided for @onbKanaYesBody.
  ///
  /// In th, this message translates to:
  /// **'เรียนตัวอักษรก่อน แล้วต่อด้วยศัพท์ N5'**
  String get onbKanaYesBody;

  /// No description provided for @onbKanaNo.
  ///
  /// In th, this message translates to:
  /// **'อ่านได้แล้ว ข้ามไป N5'**
  String get onbKanaNo;

  /// No description provided for @onbKanaNoBody.
  ///
  /// In th, this message translates to:
  /// **'เริ่มท่องศัพท์ N5 ได้เลย'**
  String get onbKanaNoBody;

  /// No description provided for @onbPaceTitle.
  ///
  /// In th, this message translates to:
  /// **'วันละเท่าไรดี?'**
  String get onbPaceTitle;

  /// No description provided for @onbPaceBody.
  ///
  /// In th, this message translates to:
  /// **'การ์ดใหม่ทุกใบจะกลับมาให้ทบทวนอีกหลายครั้ง เลือกจำนวนที่ทำได้ทุกวันสบายๆ'**
  String get onbPaceBody;

  /// No description provided for @paceLight.
  ///
  /// In th, this message translates to:
  /// **'สบายๆ'**
  String get paceLight;

  /// No description provided for @paceNormal.
  ///
  /// In th, this message translates to:
  /// **'แนะนำ'**
  String get paceNormal;

  /// No description provided for @paceIntense.
  ///
  /// In th, this message translates to:
  /// **'เข้มข้น'**
  String get paceIntense;

  /// No description provided for @cardsPerDay.
  ///
  /// In th, this message translates to:
  /// **'ใหม่ {n} ใบ/วัน'**
  String cardsPerDay(int n);

  /// No description provided for @paceMinutes.
  ///
  /// In th, this message translates to:
  /// **'ประมาณ {m} นาทีต่อวันเมื่อผ่านไปสักพัก'**
  String paceMinutes(int m);

  /// No description provided for @onbChangeLater.
  ///
  /// In th, this message translates to:
  /// **'เปลี่ยนได้ทุกเมื่อในหน้าตั้งค่า'**
  String get onbChangeLater;

  /// No description provided for @letsStart.
  ///
  /// In th, this message translates to:
  /// **'เริ่มเลย'**
  String get letsStart;

  /// No description provided for @todaySummary.
  ///
  /// In th, this message translates to:
  /// **'วันนี้ตอบไปแล้ว {n} ข้อ'**
  String todaySummary(int n);

  /// No description provided for @streakDays.
  ///
  /// In th, this message translates to:
  /// **'{n} วันติด'**
  String streakDays(int n);

  /// No description provided for @streakHelp.
  ///
  /// In th, this message translates to:
  /// **'จำนวนวันที่เรียนหรือฝึกติดต่อกัน'**
  String get streakHelp;

  /// No description provided for @streakKeep.
  ///
  /// In th, this message translates to:
  /// **'เรียนวันนี้เพื่อรักษาสถิติ'**
  String get streakKeep;

  /// No description provided for @todayNotYet.
  ///
  /// In th, this message translates to:
  /// **'วันนี้ยังไม่ได้เรียน'**
  String get todayNotYet;

  /// No description provided for @rewardDeleted.
  ///
  /// In th, this message translates to:
  /// **'ลบ {title} แล้ว'**
  String rewardDeleted(String title);

  /// No description provided for @undo.
  ///
  /// In th, this message translates to:
  /// **'เลิกทำ'**
  String get undo;

  /// No description provided for @pressBackAgain.
  ///
  /// In th, this message translates to:
  /// **'กดย้อนกลับอีกครั้งเพื่อออก'**
  String get pressBackAgain;

  /// No description provided for @grammarLevelProgress.
  ///
  /// In th, this message translates to:
  /// **'ไวยากรณ์ {level} · เริ่มแล้ว {done}/{total} หัวข้อ'**
  String grammarLevelProgress(String level, int done, int total);

  /// No description provided for @animations.
  ///
  /// In th, this message translates to:
  /// **'แอนิเมชัน'**
  String get animations;

  /// No description provided for @animationsHelp.
  ///
  /// In th, this message translates to:
  /// **'ปิดเพื่อโหมดโฟกัส: ไม่มีการเคลื่อนไหว ปุ่มไม่ยุบ เปลี่ยนข้อทันที'**
  String get animationsHelp;

  /// No description provided for @sectionInput.
  ///
  /// In th, this message translates to:
  /// **'อินพุต'**
  String get sectionInput;

  /// No description provided for @haptics.
  ///
  /// In th, this message translates to:
  /// **'การสั่นเมื่อกดและตอบ'**
  String get haptics;

  /// No description provided for @controller.
  ///
  /// In th, this message translates to:
  /// **'รองรับจอยเกมและคีย์บอร์ด'**
  String get controller;

  /// No description provided for @controllerHelp.
  ///
  /// In th, this message translates to:
  /// **'ปุ่มลูกศรเลื่อนเลือก, ปุ่มยืนยันกด, ปุ่มย้อนกลับถอยหลัง, L1/R1 เปลี่ยนแท็บ'**
  String get controllerHelp;

  /// No description provided for @swapAB.
  ///
  /// In th, this message translates to:
  /// **'สลับปุ่ม A/B (แบบ Nintendo)'**
  String get swapAB;

  /// No description provided for @swapABHelp.
  ///
  /// In th, this message translates to:
  /// **'ใช้ B เป็นปุ่มยืนยัน และ A เป็นปุ่มย้อนกลับ'**
  String get swapABHelp;

  /// No description provided for @quickAnswer.
  ///
  /// In th, this message translates to:
  /// **'ตอบด้วยปุ่มหน้าจอย'**
  String get quickAnswer;

  /// No description provided for @quickAnswerHelp.
  ///
  /// In th, this message translates to:
  /// **'ปุ่ม A, B, X, Y เลือกตัวเลือกที่ 1–4 ได้ทันที (คีย์บอร์ดกด 1–4 ได้เสมอ)'**
  String get quickAnswerHelp;

  /// No description provided for @controllerMap.
  ///
  /// In th, this message translates to:
  /// **'ปุ่มควบคุม'**
  String get controllerMap;

  /// No description provided for @controllerMapDpad.
  ///
  /// In th, this message translates to:
  /// **'ปุ่มลูกศร / สติ๊ก'**
  String get controllerMapDpad;

  /// No description provided for @controllerMapDpadDo.
  ///
  /// In th, this message translates to:
  /// **'เลื่อนไปยังปุ่มถัดไป'**
  String get controllerMapDpadDo;

  /// No description provided for @controllerMapConfirmDo.
  ///
  /// In th, this message translates to:
  /// **'กดปุ่มที่เลือก / ไปข้อถัดไป'**
  String get controllerMapConfirmDo;

  /// No description provided for @controllerMapBackDo.
  ///
  /// In th, this message translates to:
  /// **'ย้อนกลับ'**
  String get controllerMapBackDo;

  /// No description provided for @controllerMapShoulder.
  ///
  /// In th, this message translates to:
  /// **'L1 / R1'**
  String get controllerMapShoulder;

  /// No description provided for @controllerMapShoulderDo.
  ///
  /// In th, this message translates to:
  /// **'เปลี่ยนแท็บ'**
  String get controllerMapShoulderDo;

  /// No description provided for @controllerMapQuickDo.
  ///
  /// In th, this message translates to:
  /// **'ตอบตัวเลือกที่ 1–4 (เมื่อเปิดตอบด้วยปุ่มหน้าจอย)'**
  String get controllerMapQuickDo;

  /// No description provided for @controllerMapKeys.
  ///
  /// In th, this message translates to:
  /// **'คีย์บอร์ด 1–4'**
  String get controllerMapKeys;

  /// No description provided for @controllerMapKeysDo.
  ///
  /// In th, this message translates to:
  /// **'ตอบตัวเลือกที่ 1–4'**
  String get controllerMapKeysDo;

  /// No description provided for @flashcards.
  ///
  /// In th, this message translates to:
  /// **'ทวนศัพท์แบบแฟลชการ์ด'**
  String get flashcards;

  /// No description provided for @flashcardsHelp.
  ///
  /// In th, this message translates to:
  /// **'เห็นคำ นึกความหมาย แล้วพลิกการ์ดให้คะแนนตัวเอง (อีกครั้ง/ยาก/ดี/ง่าย) แบบ Anki ปิดเพื่อทวนแบบตอบคำถาม'**
  String get flashcardsHelp;

  /// No description provided for @autoPlayAudio.
  ///
  /// In th, this message translates to:
  /// **'อ่านออกเสียงเมื่อพลิกการ์ด'**
  String get autoPlayAudio;

  /// No description provided for @autoPlayAudioHelp.
  ///
  /// In th, this message translates to:
  /// **'ใช้เสียงภาษาญี่ปุ่นของเครื่อง'**
  String get autoPlayAudioHelp;

  /// No description provided for @showAnswer.
  ///
  /// In th, this message translates to:
  /// **'แสดงคำตอบ'**
  String get showAnswer;

  /// No description provided for @flashFrontHint.
  ///
  /// In th, this message translates to:
  /// **'นึกความหมายในใจ แล้วแตะการ์ดเพื่อพลิก'**
  String get flashFrontHint;

  /// No description provided for @rateAgain.
  ///
  /// In th, this message translates to:
  /// **'อีกครั้ง'**
  String get rateAgain;

  /// No description provided for @rateHard.
  ///
  /// In th, this message translates to:
  /// **'ยาก'**
  String get rateHard;

  /// No description provided for @rateGood.
  ///
  /// In th, this message translates to:
  /// **'ดี'**
  String get rateGood;

  /// No description provided for @rateEasy.
  ///
  /// In th, this message translates to:
  /// **'ง่าย'**
  String get rateEasy;

  /// No description provided for @rateHelp.
  ///
  /// In th, this message translates to:
  /// **'จำได้แค่ไหน? การ์ดจะกลับมาตามเวลาบนปุ่ม'**
  String get rateHelp;

  /// No description provided for @ivlNow.
  ///
  /// In th, this message translates to:
  /// **'<1 นาที'**
  String get ivlNow;

  /// No description provided for @ivlMinutes.
  ///
  /// In th, this message translates to:
  /// **'{n} นาที'**
  String ivlMinutes(String n);

  /// No description provided for @ivlHours.
  ///
  /// In th, this message translates to:
  /// **'{n} ชม.'**
  String ivlHours(String n);

  /// No description provided for @ivlDays.
  ///
  /// In th, this message translates to:
  /// **'{n} วัน'**
  String ivlDays(String n);

  /// No description provided for @ivlMonths.
  ///
  /// In th, this message translates to:
  /// **'{n} เดือน'**
  String ivlMonths(String n);

  /// No description provided for @ivlYears.
  ///
  /// In th, this message translates to:
  /// **'{n} ปี'**
  String ivlYears(String n);

  /// No description provided for @controllerMapFlashDo.
  ///
  /// In th, this message translates to:
  /// **'การ์ด: พลิก แล้วกด 1–4 ให้คะแนน (อีกครั้ง/ยาก/ดี/ง่าย)'**
  String get controllerMapFlashDo;

  /// No description provided for @flashKanaHint.
  ///
  /// In th, this message translates to:
  /// **'นึกเสียงอ่านในใจ แล้วแตะการ์ดเพื่อพลิก'**
  String get flashKanaHint;

  /// No description provided for @levelsTitle.
  ///
  /// In th, this message translates to:
  /// **'เลือกระดับ JLPT'**
  String get levelsTitle;

  /// No description provided for @levelsHelp.
  ///
  /// In th, this message translates to:
  /// **'เล่นการ์ดทีละระดับ เริ่มจาก N5 (ง่ายสุด) ไป N1 แต่ละระดับมีคำใหม่ต่อวันแยกกัน'**
  String get levelsHelp;

  /// No description provided for @levelWords.
  ///
  /// In th, this message translates to:
  /// **'{learned}/{total}'**
  String levelWords(int learned, int total);

  /// No description provided for @levelDueNew.
  ///
  /// In th, this message translates to:
  /// **'ทบทวน {due} · ใหม่ {fresh}'**
  String levelDueNew(int due, int fresh);

  /// No description provided for @levelSoon.
  ///
  /// In th, this message translates to:
  /// **'เร็วๆ นี้'**
  String get levelSoon;

  /// No description provided for @levelPlay.
  ///
  /// In th, this message translates to:
  /// **'เล่น'**
  String get levelPlay;

  /// No description provided for @levelDone.
  ///
  /// In th, this message translates to:
  /// **'ครบวันนี้'**
  String get levelDone;

  /// No description provided for @library.
  ///
  /// In th, this message translates to:
  /// **'คลังคำศัพท์'**
  String get library;

  /// No description provided for @librarySearchHint.
  ///
  /// In th, this message translates to:
  /// **'ค้นหา: คันจิ, คานะ, โรมาจิ หรือคำแปล'**
  String get librarySearchHint;

  /// No description provided for @libraryAll.
  ///
  /// In th, this message translates to:
  /// **'ทั้งหมด'**
  String get libraryAll;

  /// No description provided for @libraryCount.
  ///
  /// In th, this message translates to:
  /// **'{n} คำ'**
  String libraryCount(int n);

  /// No description provided for @libraryEmpty.
  ///
  /// In th, this message translates to:
  /// **'ไม่พบคำที่ค้นหา'**
  String get libraryEmpty;

  /// No description provided for @libraryDue.
  ///
  /// In th, this message translates to:
  /// **'ถึงรอบทวน'**
  String get libraryDue;

  /// No description provided for @progNotStarted.
  ///
  /// In th, this message translates to:
  /// **'ยังไม่เริ่ม'**
  String get progNotStarted;

  /// No description provided for @progLearning.
  ///
  /// In th, this message translates to:
  /// **'กำลังเรียน'**
  String get progLearning;

  /// No description provided for @progRelearning.
  ///
  /// In th, this message translates to:
  /// **'ลืม กำลังทวนใหม่'**
  String get progRelearning;

  /// No description provided for @progReview.
  ///
  /// In th, this message translates to:
  /// **'กำลังจำ'**
  String get progReview;

  /// No description provided for @progMastered.
  ///
  /// In th, this message translates to:
  /// **'จำได้แล้ว'**
  String get progMastered;

  /// No description provided for @wordProgress.
  ///
  /// In th, this message translates to:
  /// **'ความคืบหน้าของคำ'**
  String get wordProgress;

  /// No description provided for @wordProgressOpen.
  ///
  /// In th, this message translates to:
  /// **'ดูความคืบหน้าของคำนี้'**
  String get wordProgressOpen;

  /// No description provided for @statRecall.
  ///
  /// In th, this message translates to:
  /// **'โอกาสจำได้ตอนนี้'**
  String get statRecall;

  /// No description provided for @statRecallHelp.
  ///
  /// In th, this message translates to:
  /// **'คำนวณจากประวัติการตอบ ยิ่งนานไม่ได้ทวนยิ่งลดลง'**
  String get statRecallHelp;

  /// No description provided for @statNext.
  ///
  /// In th, this message translates to:
  /// **'ทบทวนครั้งถัดไป'**
  String get statNext;

  /// No description provided for @statNextIn.
  ///
  /// In th, this message translates to:
  /// **'อีก {when} ({date})'**
  String statNextIn(String when, String date);

  /// No description provided for @statNextNow.
  ///
  /// In th, this message translates to:
  /// **'ถึงเวลาแล้ว'**
  String get statNextNow;

  /// No description provided for @statStability.
  ///
  /// In th, this message translates to:
  /// **'ความจำคงทน'**
  String get statStability;

  /// No description provided for @statStabilityValue.
  ///
  /// In th, this message translates to:
  /// **'~{when}'**
  String statStabilityValue(String when);

  /// No description provided for @statStabilityHelp.
  ///
  /// In th, this message translates to:
  /// **'เวลาที่โอกาสจำได้จะลดลงเหลือราว 90% ยิ่งยาวยิ่งดี'**
  String get statStabilityHelp;

  /// No description provided for @statDifficulty.
  ///
  /// In th, this message translates to:
  /// **'ความยากของคำนี้'**
  String get statDifficulty;

  /// No description provided for @statReps.
  ///
  /// In th, this message translates to:
  /// **'ทบทวนไปแล้ว'**
  String get statReps;

  /// No description provided for @statLapses.
  ///
  /// In th, this message translates to:
  /// **'ลืมไปแล้ว'**
  String get statLapses;

  /// No description provided for @statTimes.
  ///
  /// In th, this message translates to:
  /// **'{n} ครั้ง'**
  String statTimes(int n);

  /// No description provided for @statFirstSeen.
  ///
  /// In th, this message translates to:
  /// **'เริ่มเรียนเมื่อ'**
  String get statFirstSeen;

  /// No description provided for @statLeech.
  ///
  /// In th, this message translates to:
  /// **'คำนี้ลืมบ่อย ลองอ่านประโยคตัวอย่างและออกเสียงตามดู'**
  String get statLeech;

  /// No description provided for @historyTitle.
  ///
  /// In th, this message translates to:
  /// **'ประวัติการตอบ'**
  String get historyTitle;

  /// No description provided for @historyEmpty.
  ///
  /// In th, this message translates to:
  /// **'ยังไม่เคยทบทวนคำนี้'**
  String get historyEmpty;

  /// No description provided for @historyRecall.
  ///
  /// In th, this message translates to:
  /// **'ก่อนตอบ โอกาสจำ {pct}%'**
  String historyRecall(int pct);

  /// No description provided for @notStartedBody.
  ///
  /// In th, this message translates to:
  /// **'คำนี้ยังไม่ได้เริ่มเรียน จะมาในการ์ดเมื่อถึงลำดับของระดับนี้'**
  String get notStartedBody;

  /// No description provided for @leechTag.
  ///
  /// In th, this message translates to:
  /// **'ลืมบ่อย'**
  String get leechTag;

  /// No description provided for @levelWordsList.
  ///
  /// In th, this message translates to:
  /// **'ดูคำในระดับนี้'**
  String get levelWordsList;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['th'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'th':
      return AppLocalizationsTh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
