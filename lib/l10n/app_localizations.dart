import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'VoiceType'**
  String get appTitle;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @generalSettings.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get generalSettings;

  /// No description provided for @voiceModelSettings.
  ///
  /// In en, this message translates to:
  /// **'Voice Model'**
  String get voiceModelSettings;

  /// No description provided for @textModelSettings.
  ///
  /// In en, this message translates to:
  /// **'Text Model'**
  String get textModelSettings;

  /// No description provided for @promptWorkshop.
  ///
  /// In en, this message translates to:
  /// **'Prompt Workshop'**
  String get promptWorkshop;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @logs.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logs;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @activationMode.
  ///
  /// In en, this message translates to:
  /// **'Activation Mode'**
  String get activationMode;

  /// No description provided for @tapToTalk.
  ///
  /// In en, this message translates to:
  /// **'Tap Mode'**
  String get tapToTalk;

  /// No description provided for @tapToTalkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap to start, tap to stop'**
  String get tapToTalkSubtitle;

  /// No description provided for @tapToTalkDescription.
  ///
  /// In en, this message translates to:
  /// **'Press hotkey to start recording, press again to stop'**
  String get tapToTalkDescription;

  /// No description provided for @pushToTalk.
  ///
  /// In en, this message translates to:
  /// **'Hold Mode'**
  String get pushToTalk;

  /// No description provided for @pushToTalkSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hold to record, release to stop'**
  String get pushToTalkSubtitle;

  /// No description provided for @pushToTalkDescription.
  ///
  /// In en, this message translates to:
  /// **'Hold hotkey to record, release to stop'**
  String get pushToTalkDescription;

  /// No description provided for @dictationHotkey.
  ///
  /// In en, this message translates to:
  /// **'Dictation Hotkey'**
  String get dictationHotkey;

  /// No description provided for @dictationHotkeyDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure the hotkey for starting and stopping voice dictation.'**
  String get dictationHotkeyDescription;

  /// No description provided for @pressKeyToSet.
  ///
  /// In en, this message translates to:
  /// **'Press a key to set as hotkey'**
  String get pressKeyToSet;

  /// No description provided for @clickToChangeHotkey.
  ///
  /// In en, this message translates to:
  /// **'Click to change hotkey'**
  String get clickToChangeHotkey;

  /// No description provided for @resetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get resetToDefault;

  /// No description provided for @permissions.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get permissions;

  /// No description provided for @permissionsDescription.
  ///
  /// In en, this message translates to:
  /// **'Manage system permissions for optimal performance.'**
  String get permissionsDescription;

  /// No description provided for @microphonePermission.
  ///
  /// In en, this message translates to:
  /// **'Microphone Permission'**
  String get microphonePermission;

  /// No description provided for @accessibilityPermission.
  ///
  /// In en, this message translates to:
  /// **'Accessibility Permission'**
  String get accessibilityPermission;

  /// No description provided for @testPermission.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get testPermission;

  /// No description provided for @permissionGranted.
  ///
  /// In en, this message translates to:
  /// **'Granted'**
  String get permissionGranted;

  /// No description provided for @permissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Denied'**
  String get permissionDenied;

  /// No description provided for @permissionHint.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required for voice input. Accessibility permission is needed for text insertion.'**
  String get permissionHint;

  /// No description provided for @testMicrophonePermission.
  ///
  /// In en, this message translates to:
  /// **'Test Microphone Permission'**
  String get testMicrophonePermission;

  /// No description provided for @testAccessibilityPermission.
  ///
  /// In en, this message translates to:
  /// **'Test Accessibility Permission'**
  String get testAccessibilityPermission;

  /// No description provided for @fixPermissionIssues.
  ///
  /// In en, this message translates to:
  /// **'Fix Permission Issues'**
  String get fixPermissionIssues;

  /// No description provided for @openSoundInput.
  ///
  /// In en, this message translates to:
  /// **'Open Sound Input'**
  String get openSoundInput;

  /// No description provided for @openMicrophonePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Open Microphone Privacy'**
  String get openMicrophonePrivacy;

  /// No description provided for @openAccessibilityPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Open Accessibility Privacy'**
  String get openAccessibilityPrivacy;

  /// No description provided for @microphoneInput.
  ///
  /// In en, this message translates to:
  /// **'Microphone Input'**
  String get microphoneInput;

  /// No description provided for @microphoneInputDescription.
  ///
  /// In en, this message translates to:
  /// **'Select the microphone for dictation. Enable \'Prefer Built-in Microphone\' to prevent audio interruptions when using Bluetooth headphones.'**
  String get microphoneInputDescription;

  /// No description provided for @preferBuiltInMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Prefer Built-in Microphone'**
  String get preferBuiltInMicrophone;

  /// No description provided for @preferBuiltInMicrophoneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'External microphones may cause latency or reduce transcription quality'**
  String get preferBuiltInMicrophoneSubtitle;

  /// No description provided for @currentDevice.
  ///
  /// In en, this message translates to:
  /// **'Current Device'**
  String get currentDevice;

  /// No description provided for @unknownDevice.
  ///
  /// In en, this message translates to:
  /// **'Unknown Device'**
  String get unknownDevice;

  /// No description provided for @noMicrophoneDetected.
  ///
  /// In en, this message translates to:
  /// **'No microphone detected'**
  String get noMicrophoneDetected;

  /// No description provided for @using.
  ///
  /// In en, this message translates to:
  /// **'Using'**
  String get using;

  /// No description provided for @minRecordingDuration.
  ///
  /// In en, this message translates to:
  /// **'Minimum Recording Duration'**
  String get minRecordingDuration;

  /// No description provided for @minRecordingDurationDescription.
  ///
  /// In en, this message translates to:
  /// **'Recordings shorter than this duration will be automatically ignored to avoid accidental triggers.'**
  String get minRecordingDurationDescription;

  /// No description provided for @ignoreShortRecordings.
  ///
  /// In en, this message translates to:
  /// **'Ignore recordings shorter than'**
  String get ignoreShortRecordings;

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'seconds'**
  String get seconds;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageDescription.
  ///
  /// In en, this message translates to:
  /// **'Select your preferred interface language.'**
  String get languageDescription;

  /// No description provided for @interfaceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Interface Language'**
  String get interfaceLanguage;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @simplifiedChinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get simplifiedChinese;

  /// No description provided for @logsSection.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logsSection;

  /// No description provided for @logsDescription.
  ///
  /// In en, this message translates to:
  /// **'View and manage application log files.'**
  String get logsDescription;

  /// No description provided for @logFile.
  ///
  /// In en, this message translates to:
  /// **'Log File'**
  String get logFile;

  /// No description provided for @noLogFile.
  ///
  /// In en, this message translates to:
  /// **'No Log File'**
  String get noLogFile;

  /// No description provided for @openLogDirectory.
  ///
  /// In en, this message translates to:
  /// **'Open Log Directory'**
  String get openLogDirectory;

  /// No description provided for @copyLogPath.
  ///
  /// In en, this message translates to:
  /// **'Copy Log Path'**
  String get copyLogPath;

  /// No description provided for @logPathCopied.
  ///
  /// In en, this message translates to:
  /// **'Log path copied to clipboard'**
  String get logPathCopied;

  /// No description provided for @addModel.
  ///
  /// In en, this message translates to:
  /// **'Add Model'**
  String get addModel;

  /// No description provided for @addVoiceModel.
  ///
  /// In en, this message translates to:
  /// **'Add Voice Model'**
  String get addVoiceModel;

  /// No description provided for @addTextModel.
  ///
  /// In en, this message translates to:
  /// **'Add Text Model'**
  String get addTextModel;

  /// No description provided for @editModel.
  ///
  /// In en, this message translates to:
  /// **'Edit Model'**
  String get editModel;

  /// No description provided for @editVoiceModel.
  ///
  /// In en, this message translates to:
  /// **'Edit Voice Model'**
  String get editVoiceModel;

  /// No description provided for @editTextModel.
  ///
  /// In en, this message translates to:
  /// **'Edit Text Model'**
  String get editTextModel;

  /// No description provided for @deleteModel.
  ///
  /// In en, this message translates to:
  /// **'Delete Model'**
  String get deleteModel;

  /// No description provided for @deleteModelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {vendor} / {model}?'**
  String deleteModelConfirm(Object model, Object vendor);

  /// Confirmation message for deleting a model
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {vendor} / {model}?'**
  String confirmDeleteModel(String vendor, String model);

  /// No description provided for @vendor.
  ///
  /// In en, this message translates to:
  /// **'Vendor'**
  String get vendor;

  /// No description provided for @model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get model;

  /// No description provided for @endpointUrl.
  ///
  /// In en, this message translates to:
  /// **'Endpoint URL'**
  String get endpointUrl;

  /// No description provided for @apiKey.
  ///
  /// In en, this message translates to:
  /// **'API Key'**
  String get apiKey;

  /// No description provided for @selectVendor.
  ///
  /// In en, this message translates to:
  /// **'Select Vendor'**
  String get selectVendor;

  /// No description provided for @selectModel.
  ///
  /// In en, this message translates to:
  /// **'Select Model'**
  String get selectModel;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @enterModelName.
  ///
  /// In en, this message translates to:
  /// **'Enter model name, e.g., {example}'**
  String enterModelName(Object example);

  /// No description provided for @enterApiKey.
  ///
  /// In en, this message translates to:
  /// **'Enter API Key'**
  String get enterApiKey;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get testConnection;

  /// No description provided for @testingConnection.
  ///
  /// In en, this message translates to:
  /// **'Testing connection...'**
  String get testingConnection;

  /// No description provided for @connectionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connection successful ✓'**
  String get connectionSuccess;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed, please check configuration'**
  String get connectionFailed;

  /// No description provided for @inUse.
  ///
  /// In en, this message translates to:
  /// **'In Use'**
  String get inUse;

  /// No description provided for @useThisModel.
  ///
  /// In en, this message translates to:
  /// **'Use This Model'**
  String get useThisModel;

  /// No description provided for @currentlyInUse.
  ///
  /// In en, this message translates to:
  /// **'Currently in use'**
  String get currentlyInUse;

  /// No description provided for @noModelsAdded.
  ///
  /// In en, this message translates to:
  /// **'No models added yet'**
  String get noModelsAdded;

  /// No description provided for @addVoiceModelHint.
  ///
  /// In en, this message translates to:
  /// **'Click the button below to add a speech recognition model'**
  String get addVoiceModelHint;

  /// No description provided for @addTextModelHint.
  ///
  /// In en, this message translates to:
  /// **'Click the button below to add a large language model'**
  String get addTextModelHint;

  /// No description provided for @enableTextEnhancement.
  ///
  /// In en, this message translates to:
  /// **'Enable Text Enhancement'**
  String get enableTextEnhancement;

  /// No description provided for @textEnhancementDescription.
  ///
  /// In en, this message translates to:
  /// **'Use AI to enhance and correct transcribed text.'**
  String get textEnhancementDescription;

  /// No description provided for @prompt.
  ///
  /// In en, this message translates to:
  /// **'Prompt'**
  String get prompt;

  /// No description provided for @promptDescription.
  ///
  /// In en, this message translates to:
  /// **'Customize the AI behavior for text enhancement.'**
  String get promptDescription;

  /// No description provided for @defaultPrompt.
  ///
  /// In en, this message translates to:
  /// **'Default Prompt'**
  String get defaultPrompt;

  /// No description provided for @customPrompt.
  ///
  /// In en, this message translates to:
  /// **'Custom Prompt'**
  String get customPrompt;

  /// No description provided for @useCustomPrompt.
  ///
  /// In en, this message translates to:
  /// **'Use Custom Prompt'**
  String get useCustomPrompt;

  /// No description provided for @agentName.
  ///
  /// In en, this message translates to:
  /// **'Agent Name'**
  String get agentName;

  /// No description provided for @enterAgentName.
  ///
  /// In en, this message translates to:
  /// **'Enter agent name'**
  String get enterAgentName;

  /// No description provided for @historySection.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historySection;

  /// No description provided for @noHistory.
  ///
  /// In en, this message translates to:
  /// **'No transcription history'**
  String get noHistory;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get clearHistory;

  /// No description provided for @clearHistoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all history?'**
  String get clearHistoryConfirm;

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @deleteHistoryItem.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteHistoryItem;

  /// No description provided for @searchHistory.
  ///
  /// In en, this message translates to:
  /// **'Search history...'**
  String get searchHistory;

  /// No description provided for @aboutSection.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutSection;

  /// No description provided for @appDescription.
  ///
  /// In en, this message translates to:
  /// **'VoiceType - Intelligent Voice Input Tool'**
  String get appDescription;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get checkForUpdates;

  /// No description provided for @openSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open Source Licenses'**
  String get openSourceLicenses;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;
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
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
