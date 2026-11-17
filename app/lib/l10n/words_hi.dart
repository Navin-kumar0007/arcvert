// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'words.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class WordsHi extends Words {
  WordsHi([String locale = 'hi']) : super(locale);

  @override
  String get tagline => 'आपकी फ़ाइलें इसी डिवाइस पर रहती हैं।';

  @override
  String get about => 'जानकारी';

  @override
  String get history => 'इतिहास';

  @override
  String get chooseFiles => 'फ़ाइलें चुनें';

  @override
  String get chooseOtherFiles => 'दूसरी फ़ाइलें चुनें';

  @override
  String get receiving => 'आपकी भेजी फ़ाइलें आ रही हैं...';

  @override
  String get dropAnywhere => 'या उन्हें यहाँ कहीं भी छोड़ें';

  @override
  String get dropToConvert => 'बदलने के लिए छोड़ें';

  @override
  String get saveAllBeside => 'सभी को मूल फ़ाइलों के पास सहेजें';

  @override
  String get saveAllZip => 'सभी को एक ZIP में सहेजें';

  @override
  String get openMenuAgain => 'मेन्यू फिर से खोलें';

  @override
  String get modeConvert => 'बदलें';

  @override
  String get modeTools => 'टूल';

  @override
  String fileCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count फ़ाइलें',
      one: '1 फ़ाइल',
    );
    return '$_temp0';
  }

  @override
  String andMore(Object first, int count) {
    return '$first और $count अन्य';
  }

  @override
  String get cancel => 'रद्द करें';

  @override
  String get save => 'सहेजें';

  @override
  String get share => 'शेयर करें';

  @override
  String get copy => 'कॉपी करें';

  @override
  String get showInFolder => 'फ़ोल्डर में दिखाएँ';

  @override
  String get undo => 'पहले जैसा करें';

  @override
  String get converting => 'बदल रहे हैं';

  @override
  String get done => 'हो गया';

  @override
  String get failed => 'नहीं हो सका';

  @override
  String get dragToApp => 'किसी दूसरे ऐप में खींचें';

  @override
  String get more => 'और';

  @override
  String get moreActions => 'और विकल्प';

  @override
  String get ringRotateRight => '90° दाईं ओर';

  @override
  String get ringRotateLeft => '90° बाईं ओर';

  @override
  String get ringMirror => 'आईने जैसा';

  @override
  String get ringUpsideDown => 'उल्टा';

  @override
  String get ringHalf => 'आधा';

  @override
  String ringChoice(String action, String choice) {
    return '$action, $choice';
  }

  @override
  String cancelFiles(int count) {
    return 'रद्द करें, $count फ़ाइलें';
  }

  @override
  String get nothingFits => 'कुछ भी नहीं चलेगा';

  @override
  String sizeAbout(String size) {
    return 'लगभग $size';
  }

  @override
  String sizeUpTo(String size) {
    return '$size तक';
  }

  @override
  String get trashMac => 'ट्रैश';

  @override
  String get trashWindows => 'रीसायकल बिन';

  @override
  String movedTo(Object place) {
    return '$place में भेज दिया गया।';
  }

  @override
  String couldNotMove(Object name, Object place) {
    return '$name को $place में नहीं भेजा जा सका।';
  }

  @override
  String get undoFailed => 'इसे पहले जैसा नहीं किया जा सका।';

  @override
  String get showFailed => 'इसे दिखाया नहीं जा सका।';

  @override
  String get openFailed => 'ये फ़ाइलें खुल नहीं सकीं। फिर से कोशिश करें।';

  @override
  String get sharedNothing => 'जो भेजा गया, वह खुल नहीं सका। सिर्फ़ फ़ाइलें बदली जा सकती हैं।';

  @override
  String get sharedSome => 'भेजी गई कुछ चीज़ें खुल नहीं सकीं।';

  @override
  String get folderNothing => 'उस फ़ोल्डर में ऐसा कुछ नहीं है जिसे बदला जा सके।';

  @override
  String folderTooMany(int count) {
    return 'उस फ़ोल्डर की सिर्फ़ पहली $count फ़ाइलें देखी गईं।';
  }

  @override
  String folderLeftOut(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'उस फ़ोल्डर की $count और फ़ाइलें छोड़ दी गईं।',
      one: 'उस फ़ोल्डर की 1 और फ़ाइल छोड़ दी गई।',
    );
    return '$_temp0';
  }

  @override
  String fileTooLarge(Object name, Object limit) {
    return '$name यहाँ बदलने के लिए बहुत बड़ी है (सीमा $limit)।';
  }

  @override
  String filesTooLarge(Object limit) {
    return 'ये फ़ाइलें एक साथ बदलने के लिए बहुत बड़ी हैं (सीमा $limit)। एक बार में कम फ़ाइलें लें।';
  }

  @override
  String get convertFailed => 'कुछ गड़बड़ हो गई। यह फ़ाइल बदली नहीं जा सकी।';

  @override
  String get readFailed => 'यह फ़ाइल पढ़ी नहीं जा सकी। शायद वह कहीं और चली गई है या बहुत बड़ी है।';

  @override
  String get copyDetails => 'जानकारी कॉपी करें';

  @override
  String get detailsCopied =>
      'जानकारी कॉपी हो गई। इसे बग रिपोर्ट में चिपकाएँ। इसमें फ़ाइलों के नाम नहीं हैं।';

  @override
  String get saveFailed => 'यह फ़ाइल सहेजी नहीं जा सकी। फिर से कोशिश करें।';

  @override
  String get saveAllFailed => 'ये फ़ाइलें सहेजी नहीं जा सकीं। फिर से कोशिश करें।';

  @override
  String get handOverFailed => 'यह फ़ाइल आगे नहीं भेजी जा सकी। इसकी जगह इसे सहेज लें।';

  @override
  String sizeChange(Object before, Object after) {
    return '$before से $after';
  }

  @override
  String savedBeside(Object sizes) {
    return 'मूल फ़ाइल के पास सहेजी गई। $sizes';
  }

  @override
  String saved(Object sizes) {
    return 'सहेजी गई। $sizes';
  }

  @override
  String get cantTogether => 'इस संस्करण में ये फ़ाइलें अभी एक साथ नहीं बदली जा सकतीं।';

  @override
  String get unsupportedType => 'इस तरह की फ़ाइल अभी नहीं चलती।';

  @override
  String cantConvert(Object kind) {
    return 'इस संस्करण में अभी ये नहीं बदले जा सकते: $kind।';
  }

  @override
  String get kindPdf => 'PDF फ़ाइलें';

  @override
  String get kindVideo => 'इस डिवाइस पर वीडियो';

  @override
  String get kindAudio => 'इस डिवाइस पर ऑडियो';

  @override
  String kindDocument(Object format) {
    return '$format दस्तावेज़';
  }

  @override
  String kindArchive(Object format) {
    return '$format आर्काइव';
  }

  @override
  String get kindFolder => 'फ़ोल्डर';

  @override
  String kindPicture(Object format) {
    return '$format तस्वीरें';
  }

  @override
  String get kindSubtitle => 'सबटाइटल';

  @override
  String get kindUnknown => 'यह फ़ाइल';

  @override
  String today(Object time) {
    return 'आज $time';
  }

  @override
  String yesterday(Object time) {
    return 'कल $time';
  }

  @override
  String get clearHistoryTitle => 'इतिहास मिटाएँ?';

  @override
  String get clearHistoryBody => 'इससे सिर्फ़ सूची मिटेगी। आपकी फ़ाइलें जहाँ हैं, वहीं रहेंगी।';

  @override
  String get clear => 'मिटाएँ';

  @override
  String undoneLine(Object action, Object when) {
    return 'पहले जैसा किया · $action · $when';
  }

  @override
  String get historyEmpty =>
      'आप जो सहेजेंगे, वह 30 दिन तक यहाँ दिखेगा। यह सूची इसी डिवाइस पर रहती है।';

  @override
  String get licence => 'मुफ़्त और ओपन सोर्स, Mozilla Public License 2.0 के तहत।';

  @override
  String get privacyPromise =>
      'आपकी फ़ाइलें इसी डिवाइस पर रहती हैं। कुछ भी अपलोड नहीं होता, और कोई अकाउंट, विज्ञापन या ट्रैकिंग नहीं है।';

  @override
  String get formPhoto => 'फ़ॉर्म फ़ोटो';

  @override
  String get fillInFrom => 'यहाँ से भरें';

  @override
  String get myOwnSizes => 'अपने साइज़';

  @override
  String get widthPixels => 'चौड़ाई (पिक्सेल)';

  @override
  String get heightPixels => 'ऊँचाई (पिक्सेल)';

  @override
  String get atLeastKb => 'कम से कम (KB)';

  @override
  String get atMostKb => 'ज़्यादा से ज़्यादा (KB)';

  @override
  String get checkNotice => 'नियम बदलते रहते हैं, इसलिए इन्हें अपने फ़ॉर्म की सूचना से मिला लें।';

  @override
  String get next => 'आगे';

  @override
  String get giveBoth => 'दोनों भरें, या कोई नहीं।';

  @override
  String get theseAboveZero => 'ये 0 से ज़्यादा होने चाहिए।';

  @override
  String get theseTooLarge => 'ये बहुत बड़े हैं।';

  @override
  String get smallestOverLargest => 'कम से कम वाला, ज़्यादा से ज़्यादा वाले से बड़ा नहीं हो सकता।';

  @override
  String get thisAboveZero => 'यह 0 से ज़्यादा होना चाहिए।';

  @override
  String get fileLocked => 'यह फ़ाइल लॉक है';

  @override
  String get password => 'पासवर्ड';

  @override
  String get showPassword => 'पासवर्ड दिखाएँ';

  @override
  String get hidePassword => 'पासवर्ड छिपाएँ';

  @override
  String get wrongPassword => 'यह पासवर्ड नहीं चला। फिर से कोशिश करें।';

  @override
  String get typePassword => 'पासवर्ड लिखें।';

  @override
  String get open => 'खोलें';

  @override
  String get addPassword => 'पासवर्ड लगाएँ';

  @override
  String get addPasswordWarning =>
      'इसके बिना नतीजा कोई नहीं खोल पाएगा, और भूला हुआ पासवर्ड वापस नहीं मिल सकता।';

  @override
  String get samePasswordAgain => 'वही पासवर्ड दोबारा';

  @override
  String get choosePassword => 'पासवर्ड चुनें।';

  @override
  String get passwordsDiffer => 'ये मेल नहीं खाते।';

  @override
  String get shiftTiming => 'समय खिसकाएँ';

  @override
  String get seconds => 'सेकंड';

  @override
  String get secondsHint => 'सेकंड की संख्या लिखें, जैसे 1.5';

  @override
  String get later => 'बाद में';

  @override
  String get earlier => 'पहले';

  @override
  String get shift => 'खिसकाएँ';

  @override
  String get trim => 'ट्रिम करें';

  @override
  String get start => 'शुरू';

  @override
  String get end => 'अंत';

  @override
  String get emptyFromBeginning => 'खाली छोड़ें तो शुरुआत से';

  @override
  String get emptyToEnd => 'खाली छोड़ें तो आख़िर तक';

  @override
  String get useTime => '1:30 जैसा समय लिखें।';

  @override
  String get chooseStartOrEnd => 'चुनें कि कहाँ से शुरू या कहाँ ख़त्म करना है।';

  @override
  String onlyThisLong(Object length) {
    return 'यह सिर्फ़ $length लंबा है।';
  }

  @override
  String get afterStart => 'यह शुरू के बाद होना चाहिए।';

  @override
  String get videoAtStart => 'शुरू में वीडियो';

  @override
  String get videoAtEnd => 'अंत में वीडियो';

  @override
  String get crop => 'क्रॉप करें';

  @override
  String get left => 'बाएँ';

  @override
  String get top => 'ऊपर';

  @override
  String get width => 'चौड़ाई';

  @override
  String get height => 'ऊँचाई';

  @override
  String get pictureNotShown => 'यह तस्वीर दिखाई नहीं जा सकी।';

  @override
  String get actionRotate => 'घुमाएँ';

  @override
  String get actionMerge => 'जोड़ें';

  @override
  String get actionEmail => 'ईमेल';

  @override
  String get actionCompress => 'छोटा करें';

  @override
  String actionUnder(Object size) {
    return '$size से कम';
  }

  @override
  String get actionTrim => 'ट्रिम करें';

  @override
  String get actionStripMetadata => 'मेटाडेटा हटाएँ';

  @override
  String get actionResize => 'साइज़ बदलें';

  @override
  String get actionCrop => 'क्रॉप करें';

  @override
  String get actionAddPassword => 'पासवर्ड लगाएँ';

  @override
  String get actionRemovePassword => 'पासवर्ड हटाएँ';

  @override
  String get actionWebReady => 'वेब के लिए';

  @override
  String get actionSplit => 'अलग करें';

  @override
  String get actionShiftTiming => 'समय खिसकाएँ';

  @override
  String get actionPlainText => 'सादा टेक्स्ट';

  @override
  String get actionOnePdf => 'एक PDF';

  @override
  String get actionNormaliseVolume => 'आवाज़ बराबर करें';

  @override
  String get actionMute => 'आवाज़ हटाएँ';

  @override
  String get actionFormPhoto => 'फ़ॉर्म फ़ोटो';

  @override
  String get actionFlip => 'पलटें';

  @override
  String get actionExtractPages => 'पेज निकालें';

  @override
  String get actionExtract => 'निकालें';

  @override
  String get actionChangeBitrate => 'बिटरेट बदलें';

  @override
  String cantShareHere(Object name) {
    return '$name यहाँ से शेयर नहीं की जा सकती।';
  }

  @override
  String cantHandOver(Object name) {
    return '$name आगे नहीं भेजी जा सकती।';
  }

  @override
  String noLongerThere(Object name) {
    return '$name अब वहाँ नहीं है।';
  }

  @override
  String changedSince(Object name) {
    return '$name तब से बदल गई है, इसलिए उसे छुआ नहीं गया।';
  }

  @override
  String needsPassword(Object name) {
    return '$name खोलने के लिए पासवर्ड चाहिए। यह इसी डिवाइस पर रहता है।';
  }

  @override
  String get months => 'जन॰,फ़र॰,मार्च,अप्रैल,मई,जून,जुल॰,अग॰,सित॰,अक्तू॰,नव॰,दिस॰';

  @override
  String get actionExtractAudio => 'ऑडियो निकालें';

  @override
  String get actionCompressFolder => 'फ़ोल्डर का ZIP बनाएँ';

  @override
  String get failAVideoUnreadable => 'एक वीडियो पढ़ा नहीं जा सका।';

  @override
  String get failAddPasswordNeedsOne => '\"पासवर्ड लगाएँ\" के लिए पासवर्ड चाहिए।';

  @override
  String failAnimated(Object name) {
    return 'चलती तस्वीरें अभी यहाँ नहीं बदली जा सकतीं: $name।';
  }

  @override
  String get failArchiveCantStart => 'इस ब्राउज़र में 7z और RAR फ़ाइलें शुरू नहीं हो सकीं।';

  @override
  String failAudioFormat(Object format) {
    return 'यह ऑडियो फ़ॉर्मैट नहीं बनाया जा सकता: $format।';
  }

  @override
  String get failBrowserCantMake => 'यह ब्राउज़र इस फ़ाइल को उस फ़ॉर्मैट में नहीं बदल सकता।';

  @override
  String get failBrowserCantRead =>
      'यह फ़ाइल बदली नहीं जा सकी। शायद इसका फ़ॉर्मैट यह ब्राउज़र नहीं पढ़ सकता।';

  @override
  String failCantOpenOnComputer(Object name) {
    return '$name इस कंप्यूटर पर नहीं खुल सकती।';
  }

  @override
  String failCantRead(Object name) {
    return '$name पढ़ी नहीं जा सकी।';
  }

  @override
  String failCantSaveBeside(Object name) {
    return '$name को मूल फ़ाइल के पास सहेजा नहीं जा सका।';
  }

  @override
  String failCantShare(Object name) {
    return '$name शेयर नहीं की जा सकी।';
  }

  @override
  String failCantUse(Object action, Object name) {
    return '\"$action\" $name के साथ काम नहीं कर सकता।';
  }

  @override
  String failCantUseFile(Object action) {
    return '\"$action\" इस फ़ाइल के साथ काम नहीं कर सकता।';
  }

  @override
  String get failChooseTrim => 'चुनें कि कहाँ से ट्रिम करना है।';

  @override
  String get failCropNeeded => '\"क्रॉप करें\" के लिए क्रॉप का हिस्सा चुनना होगा।';

  @override
  String failDamaged(Object name) {
    return '$name पढ़ी नहीं जा सकी। शायद यह ख़राब है।';
  }

  @override
  String failDamagedOrLocked(Object name) {
    return '$name पढ़ी नहीं जा सकी। शायद यह ख़राब है या इस पर पासवर्ड है।';
  }

  @override
  String failPartMissing(Object part, Object archive) {
    return '$part नहीं मिली। $archive के सारे हिस्से एक साथ चुनें।';
  }

  @override
  String failChoosePartsTogether(Object name) {
    return '$name कई हिस्सों में से एक है। इसके सारे हिस्से एक साथ चुनें।';
  }

  @override
  String failDamagedOrPart(Object name) {
    return '$name पढ़ी नहीं जा सकी। शायद यह ख़राब है, या कई हिस्सों में से एक है।';
  }

  @override
  String failDamagedOrTooLarge(Object name) {
    return '$name पढ़ी नहीं जा सकी। शायद यह ख़राब है, या बहुत बड़ी है।';
  }

  @override
  String get failEditDoesntFit => 'यह बदलाव इस तस्वीर पर नहीं बैठता।';

  @override
  String failEmptyArchive(Object name) {
    return '$name में कोई फ़ाइल नहीं है।';
  }

  @override
  String get failFileDamaged => 'यह फ़ाइल पढ़ी नहीं जा सकी। शायद यह ख़राब है।';

  @override
  String get failFileMoved => 'यह फ़ाइल पढ़ी नहीं जा सकी। शायद यह कहीं और चली गई है।';

  @override
  String get failFileUnreadable => 'यह फ़ाइल पढ़ी नहीं जा सकी।';

  @override
  String get failFinishSavingFirst => 'पहले दूसरी फ़ाइल को सहेजना पूरा करें।';

  @override
  String get failFormNeeded => '\"फ़ॉर्म फ़ोटो\" के लिए जानना ज़रूरी है कि फ़ॉर्म क्या माँगता है।';

  @override
  String get failFormatNotYet => 'यह फ़ॉर्मैट अभी नहीं बनाया जा सकता।';

  @override
  String failGoneBeforeSharing(Object name) {
    return '$name अब शेयर करने के लिए यहाँ नहीं है।';
  }

  @override
  String get failHeicCantStart => 'इस ब्राउज़र में HEIC फ़ोटो शुरू नहीं हो सकीं।';

  @override
  String get failHeicNeedsAndroid9 => 'HEIC फ़ोटो के लिए Android 9 या उससे नया चाहिए।';

  @override
  String get failLengthUnknown => 'इस वीडियो की लंबाई पढ़ी नहीं जा सकी।';

  @override
  String failLockedArchive(Object name) {
    return '$name पर पासवर्ड है। लॉक की हुई 7z और RAR फ़ाइलें अभी नहीं खुल सकतीं।';
  }

  @override
  String failNeedsFiles(Object action, Object count) {
    return '\"$action\" के लिए कम से कम $count फ़ाइलें चाहिए।';
  }

  @override
  String get failNoAppTakesIt => 'यहाँ कोई ऐप यह फ़ाइल नहीं ले सकता।';

  @override
  String get failNoBitrate => 'WAV और FLAC में बिटरेट की सेटिंग नहीं होती। MP3 या M4A आज़माएँ।';

  @override
  String get failNoFileMade => 'इंजन ने कोई फ़ाइल नहीं बनाई।';

  @override
  String failNoPages(Object name) {
    return '$name में कोई पेज नहीं है।';
  }

  @override
  String failNoPasswordToRemove(Object name) {
    return '$name पर हटाने के लिए कोई पासवर्ड नहीं है।';
  }

  @override
  String failNoPictureToShow(Object name) {
    return '$name में यहाँ दिखाने के लिए कोई तस्वीर नहीं है।';
  }

  @override
  String get failNoSaveChooser => 'इस फ़ोन में यह चुनने का कोई तरीका नहीं है कि फ़ाइल कहाँ सहेजें।';

  @override
  String get failNoSound => 'इस वीडियो में आवाज़ नहीं है।';

  @override
  String get failNoSubtitles => 'इस फ़ाइल में कोई सबटाइटल नहीं है।';

  @override
  String failNotAPicture(Object name) {
    return '$name को तस्वीर की तरह पढ़ा नहीं जा सका।';
  }

  @override
  String get failNotConverted => 'यह फ़ाइल बदली नहीं जा सकी।';

  @override
  String failNotFound(Object name) {
    return '$name नहीं मिली।';
  }

  @override
  String get failNotSaved => 'यह फ़ाइल सहेजी नहीं जा सकी।';

  @override
  String failNotYet(Object action) {
    return '\"$action\" अभी उपलब्ध नहीं है।';
  }

  @override
  String failOnePage(Object name) {
    return '$name में सिर्फ़ एक पेज है, इसलिए अलग करने को कुछ नहीं है।';
  }

  @override
  String failPageNotDrawn(Object page, Object name) {
    return '$name का पेज $page बनाया नहीं जा सका।';
  }

  @override
  String get failPagesFormat => 'पेज ऐसे लिखें: 1-3,7';

  @override
  String failPagesTooFull(int count, Object action) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'इन $count पेजों में इतना कुछ है कि ये पढ़ने लायक़ रहते हुए \"$action\" में नहीं आ सकते। बड़ी सीमा या \"छोटा करें\" आज़माएँ।',
      one:
          'इस पेज में इतना कुछ है कि यह पढ़ने लायक़ रहते हुए \"$action\" में नहीं आ सकता। बड़ी सीमा या \"छोटा करें\" आज़माएँ।',
    );
    return '$_temp0';
  }

  @override
  String failPasswordNeeded(Object name) {
    return '$name पर पासवर्ड है, इसलिए यह नहीं खोली गई।';
  }

  @override
  String get failPasswordUnusable => 'यह पासवर्ड इस्तेमाल नहीं किया जा सकता।';

  @override
  String get failPdfAsSmall => 'यह PDF पहले से जितनी हो सकती है, उतनी छोटी है।';

  @override
  String failPdfRotate(Object degrees) {
    return 'PDF 90, 180 या 270 डिग्री घूमती हैं, $degrees नहीं।';
  }

  @override
  String failPdfShrinksTo(Object kb, Object limit) {
    return 'यह PDF सिर्फ़ $kb KB तक छोटी होती है, जो $limit KB की सीमा से ज़्यादा है।';
  }

  @override
  String get failPhoneCantMake => 'यह फ़ोन इस साइज़ पर इस तरह की फ़ाइल नहीं बना सकता।';

  @override
  String get failPhoneCantRead => 'यह फ़ोन इस फ़ाइल का वीडियो या आवाज़ नहीं पढ़ सकता।';

  @override
  String get failPhotoDamaged => 'यह फ़ोटो पढ़ी नहीं जा सकी। शायद यह ख़राब है।';

  @override
  String failPictureRotate(Object degrees) {
    return 'तस्वीरें 90, 180 या 270 डिग्री घूमती हैं, $degrees नहीं।';
  }

  @override
  String failPictureTooBig(Object action) {
    return 'यह तस्वीर \"$action\" के लिए इतनी छोटी नहीं हो सकी।';
  }

  @override
  String get failPictureTooBigForForm => 'यह तस्वीर उस साइज़ के लिए इतनी छोटी नहीं हो सकी।';

  @override
  String failPointsOutside(Object name) {
    return '$name की एक फ़ाइल अपने फ़ोल्डर से बाहर की जगह बताती है, इसलिए इसे नहीं खोला जाएगा।';
  }

  @override
  String get failShiftNeeded => '\"समय खिसकाएँ\" के लिए बताना होगा कि कितना खिसकाना है।';

  @override
  String get failSmallestOverLargest => 'सबसे छोटा साइज़, सबसे बड़े से ज़्यादा है।';

  @override
  String get failSomethingWrong => 'कुछ गड़बड़ हो गई। यह फ़ाइल बदली नहीं जा सकी।';

  @override
  String failTooLargeForDevice(Object name) {
    return '$name इस डिवाइस पर खोलने के लिए बहुत बड़ी है।';
  }

  @override
  String failTooLargeHere(Object name) {
    return '$name यहाँ खोलने के लिए बहुत बड़ी है।';
  }

  @override
  String failTooLongToFit(Object size) {
    return 'यह वीडियो $size MB से कम में आने के लिए बहुत लंबा है।';
  }

  @override
  String failTooManyInArchive(Object name) {
    return '$name में यहाँ खोलने के लिए बहुत ज़्यादा फ़ाइलें हैं।';
  }

  @override
  String failTooManyToSave(Object name, Object count, Object limit) {
    return '$name में $count फ़ाइलें हैं, एक-एक करके सहेजने के लिए बहुत ज़्यादा। सीमा $limit है।';
  }

  @override
  String failTooMuchDetail(Object kb, Object width, Object height) {
    return 'इस तस्वीर में इतनी बारीकी है कि यह $width x $height पर $kb KB में नहीं आ सकती।';
  }

  @override
  String get failTrimLeavesNothing => 'इस ट्रिम के बाद कुछ नहीं बचता।';

  @override
  String failTryMp4(Object name) {
    return '$name पढ़ी नहीं जा सकी। MP4 या MOV आज़माएँ।';
  }

  @override
  String get failVideoCantStart => 'इस ब्राउज़र में वीडियो शुरू नहीं हो सका।';

  @override
  String get failVideoNoPicture => 'इस वीडियो में यहाँ दिखाने के लिए कोई तस्वीर नहीं है।';

  @override
  String failVideoRotate(Object degrees) {
    return 'वीडियो 90, 180 या 270 डिग्री घूमते हैं, $degrees नहीं।';
  }

  @override
  String failVideoTooBig(Object action) {
    return 'यह वीडियो \"$action\" के लिए इतना छोटा नहीं हो सका।';
  }

  @override
  String get failWidthAndHeight => 'चौड़ाई और ऊँचाई दोनों दें, या कोई नहीं।';

  @override
  String get notePictures => 'पेज अब तस्वीरें हैं, इसलिए टेक्स्ट चुना नहीं जा सकता।';

  @override
  String get noteScanned =>
      'यह PDF स्कैन की हुई है, इसलिए इसके पेज तस्वीरों के रूप में आए हैं और टेक्स्ट की तरह बदले नहीं जा सकते।';

  @override
  String noteSomePictures(Object count, Object total) {
    return '$total में से $count पेज ज़्यादातर तस्वीरें हैं, इसलिए वे तस्वीरों के रूप में आए। बाक़ी पेजों पर टेक्स्ट, बोल्ड, सरल टेबल और तस्वीरें आ गईं, पर सटीक लेआउट नहीं।';
  }

  @override
  String get noteTextEditable =>
      'टेक्स्ट, बोल्ड, सरल टेबल और तस्वीरें आ गईं, बदलने के लिए तैयार। सटीक लेआउट नहीं रखा गया।';

  @override
  String get trayStillRunning => 'Arcvert अभी भी चल रहा है';

  @override
  String get trayHowToQuit =>
      'Shift-drag काम करता रहेगा। बंद करने के लिए इस आइकन पर राइट-क्लिक करें।';

  @override
  String get trayOpen => 'Arcvert खोलें';

  @override
  String get trayQuit => 'बंद करें';

  @override
  String get keepWorkingTitle => 'आपकी फ़ाइलें बदली जा रही हैं';

  @override
  String get keepWorkingText =>
      'आप दूसरे ऐप इस्तेमाल कर सकते हैं। Arcvert काम करता रहेगा और नतीजा तैयार मिलेगा।';

  @override
  String get openAtLogin => 'लॉग इन पर खोलें';

  @override
  String get openAtLoginWhy =>
      'ताकि साइन इन करते ही Shift-drag काम करे। ज़रूरत पड़ने तक यह छिपा रहता है।';

  @override
  String get openAtLoginApprove =>
      'System Settings, General, Login Items में Arcvert को अनुमति दें।';

  @override
  String get welcomeTitle => 'Arcvert में आपका स्वागत है';

  @override
  String get welcomeText =>
      'फ़ाइलें यहीं बदलें, छोटी करें और सँवारें। कुछ भी अपलोड नहीं होता: हर फ़ाइल इसी डिवाइस पर रहती है।';

  @override
  String get welcomeSkip => 'छोड़ें';

  @override
  String get welcomeBack => 'पीछे';

  @override
  String get welcomeNext => 'आगे';

  @override
  String get welcomeStart => 'शुरू करें';

  @override
  String get practiceTitle => 'आज़माकर देखें';

  @override
  String get practiceShiftDrag => 'Shift दबाए रखकर फ़ोटो खींचें, फिर किसी हिस्से पर छोड़ें।';

  @override
  String get practiceDrag => 'फ़ोटो खींचें, फिर किसी हिस्से पर छोड़ें।';

  @override
  String get practiceHoldShift => 'खींचते समय Shift दबाए रखें।';

  @override
  String get practiceCancelled =>
      'कुछ नहीं चुना गया: बीच का घेरा रद्द करता है। फिर से आज़माएँ और किसी हिस्से पर छोड़ें।';

  @override
  String practiceDone(Object name, Object size) {
    return 'हो गया: $name, $size।';
  }

  @override
  String get practiceFailed => 'इस बार यह नहीं हुआ। आप फिर भी आगे बढ़ सकते हैं।';

  @override
  String get practicePhoto => 'अभ्यास के लिए एक नमूना फ़ोटो';

  @override
  String get tipMac =>
      'Finder से भी, किसी भी ऐप के ऊपर, यह ऐसे ही काम करता है: फ़ाइल को Shift के साथ खींचें और किसी हिस्से पर छोड़ें। छोटा करने, घुमाने और साइज़ बदलने जैसे टूल के लिए साथ में Option भी दबाएँ।';

  @override
  String get tipWindows =>
      'File Explorer से भी, किसी भी ऐप के ऊपर, यह ऐसे ही काम करता है: फ़ाइल को Shift के साथ खींचें और किसी हिस्से पर छोड़ें। छोटा करने, घुमाने और साइज़ बदलने जैसे टूल के लिए साथ में Alt भी दबाएँ।';

  @override
  String get tipAndroid => 'दूसरे ऐप में Share पर टैप करें, फिर Arcvert चुनें।';

  @override
  String get tipWeb =>
      'फ़ाइलें इस पेज पर छोड़ें या उन्हें चुनें। iPhone या iPad पर इसे Safari में खोलें, Share पर टैप करें, फिर Add to Home Screen चुनें, तब यह बिना इंटरनेट भी चलता है।';

  @override
  String get choicesTitle => 'कुछ विकल्प';

  @override
  String get language => 'भाषा';

  @override
  String get languageDevice => 'डिवाइस जैसी';

  @override
  String get checkUpdates => 'नए वर्शन देखें';

  @override
  String get checkUpdatesWhy =>
      'दिन में एक बार Arcvert अपनी वेबसाइट से पूछता है कि नया वर्शन आया है या नहीं। आपके या आपकी फ़ाइलों के बारे में कुछ नहीं भेजा जाता।';

  @override
  String get getNewest => 'सबसे नया वर्शन पाएँ';

  @override
  String get getNewestWhy =>
      'डाउनलोड पेज आपके ब्राउज़र में खुलता है। Arcvert खुद इंटरनेट इस्तेमाल नहीं कर सकता।';

  @override
  String updateReady(Object version) {
    return 'Arcvert $version आ गया है।';
  }

  @override
  String get updateGet => 'डाउनलोड करें';

  @override
  String get updateLater => 'बाद में';

  @override
  String pageFailed(Object address) {
    return 'पेज नहीं खुल सका। पता है: $address';
  }

  @override
  String get showGuide => 'गाइड फिर से दिखाएँ';

  @override
  String get settingsTitle => 'सेटिंग';

  @override
  String get resultsWhere => 'नतीजे कहाँ जाएँ';

  @override
  String get resultsBeside => 'मूल फ़ाइल के पास';

  @override
  String get resultsInFolder => 'एक फ़ोल्डर में';

  @override
  String resultsFolderIs(Object folder) {
    return 'नतीजे $folder में जाते हैं';
  }

  @override
  String get resultsChange => 'बदलें';

  @override
  String resultsFolderGone(Object folder) {
    return '$folder इस्तेमाल नहीं हो सका, इसलिए नतीजे मूल फ़ाइलों के पास रखे गए। सेटिंग में कोई दूसरा फ़ोल्डर चुनें।';
  }

  @override
  String saveAllTo(Object folder) {
    return 'सभी को $folder में सहेजें';
  }

  @override
  String savedIn(Object folder, Object sizes) {
    return '$folder में सहेजी गई। $sizes';
  }

  @override
  String get theme => 'थीम';

  @override
  String get themeSystem => 'सिस्टम जैसी';

  @override
  String get themeLight => 'हल्की';

  @override
  String get themeDark => 'गहरी';

  @override
  String get showPreviews => 'झलक दिखाएँ';

  @override
  String get showPreviewsWhy =>
      'हर फ़ाइल के पहले पेज की छोटी तस्वीर, पहले और बाद में। इसी डिवाइस पर बनती है और कभी रखी नहीं जाती।';

  @override
  String get reorderTitle => 'इन्हें क्रम में लगाएँ';

  @override
  String get reorderHint =>
      'ये ऊपर से नीचे के क्रम में जुड़ेंगी। इन्हें खींचें, या तीरों का इस्तेमाल करें।';

  @override
  String reorderUp(Object name) {
    return '$name को ऊपर ले जाएँ';
  }

  @override
  String reorderDown(Object name) {
    return '$name को नीचे ले जाएँ';
  }

  @override
  String get previewTitle => 'झलक';

  @override
  String get previewHide => 'झलक छिपाएँ';

  @override
  String get previewShow => 'झलक दिखाएँ';

  @override
  String get previewBefore => 'पहले';

  @override
  String get previewAfter => 'बाद में';

  @override
  String get previewCant => 'इसकी झलक नहीं दिख सकती';

  @override
  String get previewLocked => 'लॉक है। पासवर्ड देने के बाद दिखेगी।';

  @override
  String previewPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पेज',
      one: '1 पेज',
    );
    return '$_temp0';
  }

  @override
  String previewOf(Object name) {
    return '$name की झलक';
  }

  @override
  String get previewCompare => 'पहले और बाद में। तुलना के लिए रेखा खिसकाएँ।';

  @override
  String get previewEnlarge => 'बड़ा करें';

  @override
  String get previewCompareShort => 'तुलना';

  @override
  String get modeFit => 'फ़िट करें';

  @override
  String get homeTitle => 'फ़ाइल को डायल पर छोड़ें';

  @override
  String get homeSubtitle => 'बदलें, छोटा करें या सँवारें। असली फ़ाइल कभी नहीं बदलती।';

  @override
  String get offlineBadge => 'ऑफ़लाइन · कुछ भी अपलोड नहीं होता';

  @override
  String get fromAnyApp => 'किसी भी ऐप से';

  @override
  String get shiftDragAction => 'फ़ाइल खींचें';

  @override
  String get shiftDragExplain =>
      'डायल आपके कर्सर पर, किसी भी ऐप के ऊपर खुलता है। किसी हिस्से पर छोड़ दें।';

  @override
  String get toolsKeyHint => 'से टूल मिलते हैं: काटना, घुमाना, आकार बदलना';

  @override
  String get fitChat => 'चैट ऐप';

  @override
  String get fitChatNote => 'फ़ोन पर साफ़, भेजने में जल्दी';

  @override
  String get fitEmail => 'ईमेल';

  @override
  String get fitEmailNote => 'अटैचमेंट की आम सीमा से कम';

  @override
  String get fitSize => 'तय आकार से कम';

  @override
  String get fitSizeNote => '100 KB, 500 KB या 1 MB';

  @override
  String get fitForm => 'फ़ॉर्म की फ़ोटो और हस्ताक्षर';

  @override
  String get fitFormNote => 'फ़ॉर्म जितने पिक्सेल और KB माँगे, ठीक उतने';

  @override
  String get recent => 'हाल के';

  @override
  String get allHistory => 'पूरा इतिहास';

  @override
  String get recentEmpty => 'आप जो नतीजे सहेजेंगे, वे यहाँ दिखेंगे।';

  @override
  String get privacyNote => 'सब कुछ इसी डिवाइस पर होता है। न खाता, न अपलोड, न ट्रैकिंग।';

  @override
  String get familyPhotos => 'फ़ोटो और HEIC';

  @override
  String get familyPdf => 'PDF और Word';

  @override
  String get familyMedia => 'वीडियो और आवाज़';

  @override
  String get familyArchives => 'ZIP, 7z, RAR';

  @override
  String get familySubtitles => 'सबटाइटल';

  @override
  String get addFiles => 'फ़ाइलें जोड़ें';

  @override
  String get clearFiles => 'हटाएँ';

  @override
  String get dragOutHint => 'मेल, चैट या फ़ोल्डर में खींचें';

  @override
  String get keysChoose => 'कोई हिस्सा चुनें';

  @override
  String get keysRing => 'बाहरी घेरे पर उसके विकल्प';

  @override
  String get keysRun => 'चलाएँ';

  @override
  String get keysClose => 'डायल बंद करें';

  @override
  String get keyArrows => 'तीर कुंजियाँ';

  @override
  String get cleanSignature => 'हस्ताक्षर साफ़ करें';

  @override
  String get cleanSignatureWhy =>
      'स्याही तक काटता है, काग़ज़ को सफ़ेद और स्याही को गहरा करता है। सिर्फ़ हस्ताक्षर के लिए: फ़ॉर्म बदली हुई फ़ोटो नहीं लेते।';

  @override
  String get failNoSignature =>
      'कोई हस्ताक्षर नहीं मिला। सादे काग़ज़ पर गहरी स्याही से हस्ताक्षर करें, और सिर्फ़ हस्ताक्षर को फ़्रेम में रखें।';

  @override
  String get actionScannedDocument => 'स्कैन किया दस्तावेज़';

  @override
  String get fitScan => 'स्कैन किया दस्तावेज़';

  @override
  String get fitScanNote => 'पन्नों की फ़ोटो से एक साफ़ PDF';

  @override
  String failScanTooBig(int kb) {
    return 'इन पन्नों को $kb KB से छोटा करके पढ़ने लायक नहीं रखा जा सका। कम पन्ने या बड़ी सीमा आज़माएँ।';
  }

  @override
  String get ringBalanced => 'संतुलित';

  @override
  String get ringBestQuality => 'सबसे अच्छी क्वालिटी';

  @override
  String get ringSmallest => 'सबसे छोटा';

  @override
  String get failPictureAsSmall =>
      'यह तस्वीर उस स्तर पर पहले से ही इतनी छोटी है। संतुलित या सबसे छोटा आज़माएँ।';

  @override
  String get choosePages => 'पन्ने चुनें';

  @override
  String get pagesField => 'पन्ने, जैसे 1-3, 7';

  @override
  String get pagesAll => 'सभी';

  @override
  String get pagesNone => 'कोई नहीं';

  @override
  String pagesChosen(int count, int total) {
    return '$total में से $count चुने';
  }

  @override
  String pageNumber(int number) {
    return 'पन्ना $number';
  }

  @override
  String get pagesCantShow => 'पन्ने यहाँ दिखाए नहीं जा सकते, पर आप उन्हें लिख सकते हैं।';

  @override
  String get extractPagesGo => 'निकालें';

  @override
  String get failNoPagesChosen => 'कम से कम एक पन्ना चुनें।';

  @override
  String failBadPageRange(Object part) {
    return '\"$part\" कोई पन्ना या दायरा नहीं है। पन्ने ऐसे लिखें: 1-3, 7।';
  }

  @override
  String failPageOutOfRange(int page, int total) {
    return 'पन्ना $page नहीं है। इस PDF में $total पन्ने हैं।';
  }

  @override
  String get learnOrder => 'सबसे ज़्यादा इस्तेमाल होने वाले काम पहले दिखाएँ';

  @override
  String get learnOrderWhy =>
      'सिर्फ़ इसी डिवाइस पर सीखा जाता है। मेनू का क्रम ऐप अगली बार खुलने पर बदलता है, इस्तेमाल के दौरान कभी नहीं।';

  @override
  String get learnOrderForget => 'सीखा हुआ भूल जाएँ';

  @override
  String get learnOrderForgotten => 'ऐप अगली बार खुलने पर मेनू अपने सामान्य क्रम में लौट आएँगे।';

  @override
  String get triggerKey => 'दूसरे ऐप से खींचने की कुंजी';

  @override
  String get triggerKeyWhy =>
      'फ़ाइल खींचते समय इसे दबाए रखें तो मेनू खुलता है। Option या Alt से अब भी टूल मिलते हैं।';

  @override
  String menuSpeedNone(Object key) {
    return '$key दबाकर कोई फ़ाइल खींचें, तो पता चलेगा कि मेनू कितनी जल्दी खुलता है।';
  }

  @override
  String menuSpeed(int usual, int slowest, int count) {
    return 'पिछली $count बार मेनू आम तौर पर $usual ms में खुला, ज़्यादा से ज़्यादा $slowest ms में।';
  }

  @override
  String get help => 'मदद';

  @override
  String get helpSearch => 'मदद में खोजें';

  @override
  String helpNoMatch(Object query) {
    return 'मदद में \"$query\" से जुड़ा कुछ नहीं मिला।';
  }

  @override
  String get helpQuestions => 'आम सवाल';

  @override
  String get helpShortcuts => 'कीबोर्ड शॉर्टकट';

  @override
  String get helpSupport => 'सहायता';

  @override
  String get helpOffline =>
      'मदद बिना इंटरनेट के चलती है। रिपोर्ट और सुझाव आपके ईमेल ऐप या ब्राउज़र में खुलते हैं, ताकि आप उन्हें भेजें।';

  @override
  String get faqConvertQ => 'फ़ाइल कैसे बदलूँ?';

  @override
  String get faqConvertA =>
      'फ़ाइलें चुनें या यहाँ छोड़ें, फिर डायल पर कोई हिस्सा चुनें। Convert फ़ॉर्मेट बदलता है, Make it fit फ़ाइल को किसी काम के लायक छोटा करता है, और Tools में बाकी सब है। नतीजे नीचे दिखते हैं, सेव करने के लिए तैयार।';

  @override
  String get faqShiftDragQ => 'फ़ाइल खींचने पर मेनू नहीं दिखता।';

  @override
  String faqShiftDragA(Object key) {
    return 'Arcvert चालू होना चाहिए, इसलिए Settings में Open at login चालू करें। Finder या Explorer में कोई फ़ाइल खींचना शुरू करें, फिर $key दबाए रखें। दूसरे ऐप के अंदर का टेक्स्ट या तस्वीर फ़ाइल नहीं होती, इसलिए उनसे मेनू नहीं खुलता।';
  }

  @override
  String get faqAltShiftQ => 'Alt और Shift साथ दबाने से कीबोर्ड की भाषा बदल जाती है।';

  @override
  String get faqAltShiftA =>
      'यह Windows का अपना शॉर्टकट है। Settings में कुंजी के लिए Control चुनें, या Windows की भाषा सेटिंग में यह शॉर्टकट बंद करें।';

  @override
  String get faqWhereQ => 'मेरे नतीजे कहाँ जाते हैं?';

  @override
  String get faqWhereDesktopA =>
      'मूल फ़ाइल के पास, ऐसे नाम से कि कभी कुछ न बदले, या Settings में चुने फ़ोल्डर में।';

  @override
  String get faqWhereOtherA =>
      'हर एक को कहाँ सेव करना है, आप चुनते हैं, या Save all से सबकी एक ZIP बनती है।';

  @override
  String get faqUndoQ => 'क्या बदलाव वापस हो सकता है?';

  @override
  String get faqUndoDesktopA =>
      'हाँ। History में 30 दिन तक सेव हुई चीज़ें दिखती हैं, और Undo नतीजे को Trash या Recycle Bin में भेज देता है। मूल फ़ाइलें कभी नहीं बदलतीं।';

  @override
  String get faqUndoOtherA =>
      'मूल फ़ाइलें कभी नहीं बदलतीं, इसलिए वापस करने को कुछ नहीं है। History में बनी चीज़ें दिखती हैं, और न चाहिए तो नतीजा किसी भी फ़ाइल की तरह मिटाया जा सकता है।';

  @override
  String get faqUploadQ => 'क्या मेरी फ़ाइलें कहीं अपलोड होती हैं?';

  @override
  String get faqUploadA =>
      'नहीं। सब कुछ इसी डिवाइस पर होता है, ब्राउज़र में भी, और Arcvert में न अकाउंट हैं, न विज्ञापन, न ट्रैकिंग।';

  @override
  String get faqFormQ => 'फ़ॉर्म कहता है कि मेरी फ़ोटो या हस्ताक्षर का आकार गलत है।';

  @override
  String get faqFormA =>
      'Make it fit में Form photo लें, फ़ॉर्म चुनें या उसके माप लिखें, और उन्हें फ़ॉर्म की सूचना से मिलाएँ, क्योंकि फ़ॉर्म इन्हें बदलते रहते हैं। कुछ 1 KB को 1000 बाइट गिनते हैं और कुछ 1024: Arcvert दोनों पूरे करता है।';

  @override
  String get faqPdfTextQ => 'PDF छोटी करने के बाद टेक्स्ट क्यों नहीं चुना जाता?';

  @override
  String get faqPdfTextA =>
      'स्कैन को छोटा करने के लिए उसके पन्ने तस्वीरों के रूप में दोबारा बनते हैं, यही एक तरीका है। नतीजे में यह लिखा होता है। टेक्स्ट चाहिए तो मूल फ़ाइल रखें।';

  @override
  String get faqLockedQ => 'फ़ाइल पासवर्ड माँगती है।';

  @override
  String get faqLockedA =>
      'PDF और ZIP अपना पासवर्ड माँगती हैं, और वह सिर्फ़ उसी काम में इस्तेमाल होता है। लॉक की हुई 7z और RAR फ़ाइलें अभी नहीं खुल सकतीं।';

  @override
  String get faqRarPartsQ => 'मेरी RAR कई हिस्सों में है।';

  @override
  String get faqRarPartsA =>
      'सारे हिस्से एक साथ चुनें या छोड़ें, तो वे एक आर्काइव की तरह खुलते हैं। Mac या Windows पर एक हिस्सा काफ़ी है: बाकी उसके पास ही मिल जाते हैं।';

  @override
  String get faqMacOpenQ => 'macOS कहता है कि ऐप की जाँच नहीं हो सकती।';

  @override
  String get faqMacOpenA =>
      'Arcvert पर अभी Apple का साइन नहीं है। System Settings खोलें, फिर Privacy & Security, और Open Anyway चुनें।';

  @override
  String get faqWindowsWarnQ => 'ऐप खोलने पर Windows चेतावनी देता है।';

  @override
  String get faqWindowsWarnA =>
      'जब तक ऐप साइन नहीं होता, Windows SmartScreen चेतावनी दे सकता है। More info चुनें, फिर Run anyway।';

  @override
  String get faqSlowQ => 'वीडियो में बहुत समय लग रहा है।';

  @override
  String get faqSlowA =>
      'वीडियो सबसे भारी काम है, जो इस डिवाइस के अपने एन्कोडर करते हैं। फ़ोन पर काम चलते समय आप ऐप छोड़ सकते हैं, और Cancel बिना कुछ छोड़े उसे रोक देता है।';

  @override
  String get shortcutMove => 'हिस्सों के बीच जाएँ';

  @override
  String get shortcutRun => 'चुना हुआ हिस्सा चलाएँ';

  @override
  String get shortcutChoices => 'किसी हिस्से के विकल्पों में जाएँ और वापस आएँ, या अगला पन्ना';

  @override
  String get shortcutClose => 'मेनू बंद करें';

  @override
  String get shortcutTools => 'Shift-drag के दौरान: टूल दिखाएँ';

  @override
  String get shortcutCompare => 'प्रीव्यू पर तुलना की रेखा खिसकाएँ';

  @override
  String get reportProblem => 'समस्या बताएँ';

  @override
  String get reportProblemWhy =>
      'एक रिपोर्ट भर देता है, जिसे आप पढ़कर खुद भेजें। आपके भेजे बिना कुछ नहीं जाता।';

  @override
  String get reportWhatHappened => 'क्या हुआ?';

  @override
  String get reportHint =>
      'जो फ़ाइल नहीं बदली, उसकी Copy details यहाँ चिपकाएँ। कोई निजी बात न लिखें।';

  @override
  String get reportIncludes => 'यह भी जुड़ेगा:';

  @override
  String get reportOpen => 'GitHub पर रिपोर्ट करें';

  @override
  String get reportCopy => 'इसकी जगह कॉपी करें';

  @override
  String get reportCopied => 'कॉपी हो गया। इसे ईमेल या रिपोर्ट में चिपकाएँ।';

  @override
  String get suggestFeature => 'कोई सुविधा सुझाएँ';

  @override
  String get suggestFeatureWhy => 'एक संदेश भर देता है, जिसे आप पूरा करके भेजें।';

  @override
  String whatsNewTitle(Object version) {
    return '$version में नया क्या है';
  }

  @override
  String get whatsNewPdfPassword => 'हर प्लेटफ़ॉर्म पर PDF में पासवर्ड जोड़ें, AES-256 के साथ।';

  @override
  String get whatsNewRarParts => 'कई हिस्सों वाली RAR फ़ाइलें एक आर्काइव की तरह खुलती हैं।';

  @override
  String get whatsNewMenuSpeed => 'Settings बताता है कि Shift-drag मेनू कितनी जल्दी खुलता है।';

  @override
  String get whatsNewHelp => 'मदद, जिसमें आम सवाल, शॉर्टकट और समस्या बताने का तरीका है।';

  @override
  String whatsNewReady(Object version) {
    return 'Arcvert $version आ गया है। मदद में देखें कि नया क्या है।';
  }

  @override
  String get whatsNewSee => 'देखें';

  @override
  String get reportEmail => 'ईमेल से भेजें';

  @override
  String get suggestOnGitHub => 'GitHub पर सुझाएँ';

  @override
  String writeToUs(Object address) {
    return 'या $address पर लिखें';
  }

  @override
  String get whatsNewName =>
      'ShiftDrop अब Arcvert है: वही ऐप, नए नाम के साथ, क्योंकि ShiftDrop नाम का एक और ऐप पहले से था। Mac या Windows पर सेटिंग और History साथ आते हैं।';

  @override
  String get whatsNewLook =>
      'लाइट और डार्क में नया रूप, फ़ाइलों और नतीजों के प्रीव्यू, और Settings।';

  @override
  String get whatsNewPages =>
      'PDF के पन्ने उनकी तस्वीरें देखकर चुनें, और Compress तीन स्तरों पर करें।';

  @override
  String get keepAsSlice => 'Make it fit स्लाइस के रूप में रखें';

  @override
  String get keepAsSliceWhy =>
      'अगली बार बस एक कदम: Make it fit में सबसे पहले, और Mac या Windows पर Shift-drag मेनू में भी।';

  @override
  String slicesFull(int count) {
    return 'आपके पास $count स्लाइस हैं, जितने रखे जा सकते हैं। दूसरा रखने के लिए सेटिंग में एक हटाएँ।';
  }

  @override
  String get sliceName => 'स्लाइस का नाम';

  @override
  String get sliceNameHint => 'कॉलेज फ़ॉर्म';

  @override
  String get sliceNameNeeded => 'इसे एक नाम दें।';

  @override
  String sliceNameTaken(Object name) {
    return '$name नाम का स्लाइस पहले से है।';
  }

  @override
  String sliceKept(Object name) {
    return '$name अब Make it fit में है।';
  }

  @override
  String get yourSlices => 'आपके Make it fit स्लाइस';

  @override
  String get yourSlicesWhy =>
      'आपके अपने साइज़, बस एक कदम दूर: Make it fit में सबसे पहले, और Mac या Windows पर Shift-drag मेनू में भी। तस्वीरें JPG बनती हैं, हर एक के बीच के हिस्से से।';

  @override
  String get addSlice => 'स्लाइस जोड़ें';

  @override
  String get newSlice => 'नया स्लाइस';

  @override
  String get changeSlice => 'स्लाइस बदलें';

  @override
  String get deleteSlice => 'हटाएँ';

  @override
  String sliceDeleted(Object name) {
    return '$name हटाया गया।';
  }

  @override
  String get sliceAnySize => 'कोई भी साइज़';

  @override
  String sliceUpToKb(int kb) {
    return '$kb KB तक';
  }

  @override
  String sliceAtLeastKb(int kb) {
    return 'कम से कम $kb KB';
  }

  @override
  String get sliceSignature => 'हस्ताक्षर';

  @override
  String get faqSlicesQ => 'क्या मैं अपने फ़ॉर्म के साइज़ अगली बार के लिए रख सकता हूँ?';

  @override
  String get faqSlicesA =>
      'हाँ। Form photo में साइज़ भरें, Make it fit स्लाइस के रूप में रखें चालू करें और नाम दें। यह Make it fit में सबसे पहले आता है, और Mac या Windows पर Shift-drag मेनू में भी, और एक कदम में वही JPG बनाता है, फ़ोटो के बीच के हिस्से से। फ़्रेम खुद चुनने के लिए Form photo खोलें और सूची से अपना स्लाइस चुनें। सेटिंग में आपके स्लाइस हैं, बदलने या हटाने के लिए।';

  @override
  String get moveSettings => 'अपनी सेटिंग दूसरे डिवाइस पर ले जाएँ';

  @override
  String get moveSettingsWhy =>
      'अपनी पसंद और स्लाइस एक फ़ाइल में सेव करें, फिर दूसरे डिवाइस पर ले आएँ। इसमें कोई फ़ाइल, फ़ोल्डर या हिस्ट्री नहीं जाती।';

  @override
  String get exportSettings => 'सेटिंग फ़ाइल में सेव करें';

  @override
  String get importSettings => 'फ़ाइल से सेटिंग लाएँ';

  @override
  String get settingsExported => 'सेटिंग सेव हो गईं।';

  @override
  String get settingsExportFailed => 'सेटिंग फ़ाइल सेव नहीं हो सकी। फिर कोशिश करें।';

  @override
  String get settingsNotAFile => 'यह Arcvert की सेटिंग फ़ाइल नहीं है।';

  @override
  String get settingsReadFailed => 'वह फ़ाइल पढ़ी नहीं जा सकी। फिर कोशिश करें।';

  @override
  String get importTitle => 'ये सेटिंग लाएँ?';

  @override
  String get importWhat =>
      'थीम, भाषा और आपकी बाकी पसंद फ़ाइल वाली हो जाएँगी। इस डिवाइस की अपनी चीज़ें, जैसे नतीजों का फ़ोल्डर, वैसी ही रहेंगी।';

  @override
  String importSlices(int added, int changed) {
    return 'स्लाइस: $added नए, $changed बदले।';
  }

  @override
  String importSlicesLeftOut(int count, int most) {
    return '$count और नहीं आ सके: जगह $most की ही है।';
  }

  @override
  String get importDo => 'लाएँ';

  @override
  String get settingsImported => 'सेटिंग आ गईं।';

  @override
  String get faqMoveQ => 'अपनी सेटिंग और स्लाइस दूसरे डिवाइस पर कैसे ले जाऊँ?';

  @override
  String get faqMoveA =>
      'सेटिंग में सेटिंग फ़ाइल में सेव करें चुनें, और फ़ाइल ईमेल या USB स्टिक से दूसरे डिवाइस पर ले जाएँ। वहाँ फ़ाइल से सेटिंग लाएँ चुनें। आपकी पसंद और स्लाइस आते हैं, आपकी फ़ाइलें या हिस्ट्री कभी नहीं।';

  @override
  String get faqRightClickQ => 'क्या मैं फ़ाइल पर राइट-क्लिक करके शुरू कर सकता हूँ?';

  @override
  String get faqRightClickMacA =>
      'हाँ। Finder में फ़ाइलों या फ़ोल्डर पर राइट-क्लिक करें और Quick Actions या Services में Convert with Arcvert चुनें: डायल वहीं दिखता है, और नतीजा मूल फ़ाइल के पास सेव होता है। Open With में Arcvert चुनने पर वे विंडो में खुलती हैं।';

  @override
  String get faqRightClickWindowsA =>
      'हाँ। File Explorer में फ़ाइलों या फ़ोल्डर पर राइट-क्लिक करें और Convert with Arcvert चुनें। Windows 11 पर यह Show more options में है। Arcvert उन्हें चुनकर खुलता है, बनाने के लिए तैयार।';
}
