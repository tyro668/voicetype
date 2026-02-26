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
  /// **'Prompt Settings'**
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

  /// No description provided for @meetingHotkey.
  ///
  /// In en, this message translates to:
  /// **'Meeting Recording Hotkey'**
  String get meetingHotkey;

  /// No description provided for @meetingHotkeyDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure the hotkey for starting and ending meeting recording. Press once to start, press again to end.'**
  String get meetingHotkeyDescription;

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
  /// **'Copy Path'**
  String get copyLogPath;

  /// No description provided for @logPathCopied.
  ///
  /// In en, this message translates to:
  /// **'Log path copied to clipboard'**
  String get logPathCopied;

  /// No description provided for @tip.
  ///
  /// In en, this message translates to:
  /// **'Tip'**
  String get tip;

  /// No description provided for @logsTip.
  ///
  /// In en, this message translates to:
  /// **'Log files contain application runtime records for troubleshooting. If the app encounters issues, you can provide this log file to developers for analysis.'**
  String get logsTip;

  /// No description provided for @recordingStorage.
  ///
  /// In en, this message translates to:
  /// **'Recording Storage'**
  String get recordingStorage;

  /// No description provided for @recordingStorageDescription.
  ///
  /// In en, this message translates to:
  /// **'View and manage recording audio files.'**
  String get recordingStorageDescription;

  /// No description provided for @recordingFiles.
  ///
  /// In en, this message translates to:
  /// **'Recording Files'**
  String get recordingFiles;

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'files'**
  String get files;

  /// No description provided for @openRecordingFolder.
  ///
  /// In en, this message translates to:
  /// **'Open Folder'**
  String get openRecordingFolder;

  /// No description provided for @copyPath.
  ///
  /// In en, this message translates to:
  /// **'Copy Path'**
  String get copyPath;

  /// No description provided for @clearRecordingFiles.
  ///
  /// In en, this message translates to:
  /// **'Clear Files'**
  String get clearRecordingFiles;

  /// No description provided for @clearRecordingFilesConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete all recording files? This action cannot be undone.'**
  String get clearRecordingFilesConfirm;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

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

  /// No description provided for @current.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get current;

  /// No description provided for @test.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get test;

  /// No description provided for @currentSystemPrompt.
  ///
  /// In en, this message translates to:
  /// **'Current System Prompt'**
  String get currentSystemPrompt;

  /// No description provided for @customPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Prompt'**
  String get customPromptTitle;

  /// No description provided for @enableCustomPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enable Custom Prompt'**
  String get enableCustomPrompt;

  /// No description provided for @customPromptEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled: Text enhancement will use custom prompt below'**
  String get customPromptEnabled;

  /// No description provided for @customPromptDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled: Text enhancement will use system default prompt'**
  String get customPromptDisabled;

  /// No description provided for @agentNamePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Use {agentName} as placeholder for agent name'**
  String agentNamePlaceholder(Object agentName);

  /// No description provided for @systemPrompt.
  ///
  /// In en, this message translates to:
  /// **'System Prompt'**
  String get systemPrompt;

  /// No description provided for @saveAgentConfig.
  ///
  /// In en, this message translates to:
  /// **'Save Agent Configuration'**
  String get saveAgentConfig;

  /// No description provided for @restoreDefault.
  ///
  /// In en, this message translates to:
  /// **'Restore Default'**
  String get restoreDefault;

  /// No description provided for @testYourAgent.
  ///
  /// In en, this message translates to:
  /// **'Test Your Agent'**
  String get testYourAgent;

  /// No description provided for @testAgentDescription.
  ///
  /// In en, this message translates to:
  /// **'Test with current text model and agent prompt.'**
  String get testAgentDescription;

  /// No description provided for @testInput.
  ///
  /// In en, this message translates to:
  /// **'Test Input'**
  String get testInput;

  /// No description provided for @enterTestText.
  ///
  /// In en, this message translates to:
  /// **'Enter text to polish...'**
  String get enterTestText;

  /// No description provided for @running.
  ///
  /// In en, this message translates to:
  /// **'Running...'**
  String get running;

  /// No description provided for @runTest.
  ///
  /// In en, this message translates to:
  /// **'Run Test'**
  String get runTest;

  /// No description provided for @outputResult.
  ///
  /// In en, this message translates to:
  /// **'Output Result'**
  String get outputResult;

  /// No description provided for @outputWillAppearHere.
  ///
  /// In en, this message translates to:
  /// **'Output will appear here'**
  String get outputWillAppearHere;

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

  /// No description provided for @historyHint.
  ///
  /// In en, this message translates to:
  /// **'Use hotkey to start recording, transcription results will appear here'**
  String get historyHint;

  /// No description provided for @clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get clearHistory;

  /// No description provided for @clearHistoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all history? This action cannot be undone.'**
  String get clearHistoryConfirm;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

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

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

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
  /// **'A voice input tool that supports multiple cloud LLMs and local Whisper models, converting speech to text quickly.'**
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

  /// No description provided for @networkSettings.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get networkSettings;

  /// No description provided for @networkSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure the network proxy mode for the application.'**
  String get networkSettingsDescription;

  /// No description provided for @systemSettings.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemSettings;

  /// No description provided for @systemSettingsDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure system-level settings such as startup behavior and network proxy.'**
  String get systemSettingsDescription;

  /// No description provided for @launchAtLogin.
  ///
  /// In en, this message translates to:
  /// **'Launch at Login'**
  String get launchAtLogin;

  /// No description provided for @launchAtLoginDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically start VoiceType when you log in.'**
  String get launchAtLoginDescription;

  /// No description provided for @launchAtLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to enable launch at login'**
  String get launchAtLoginFailed;

  /// No description provided for @disableLaunchAtLoginFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to disable launch at login'**
  String get disableLaunchAtLoginFailed;

  /// No description provided for @proxyConfig.
  ///
  /// In en, this message translates to:
  /// **'Proxy Configuration'**
  String get proxyConfig;

  /// No description provided for @useSystemProxy.
  ///
  /// In en, this message translates to:
  /// **'Use System Proxy'**
  String get useSystemProxy;

  /// No description provided for @systemProxySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Requests follow the system network proxy configuration.'**
  String get systemProxySubtitle;

  /// No description provided for @noProxy.
  ///
  /// In en, this message translates to:
  /// **'No Proxy'**
  String get noProxy;

  /// No description provided for @noProxySubtitle.
  ///
  /// In en, this message translates to:
  /// **'All requests connect directly without any proxy.'**
  String get noProxySubtitle;

  /// No description provided for @inputMonitoringRequired.
  ///
  /// In en, this message translates to:
  /// **'Input Monitoring Required'**
  String get inputMonitoringRequired;

  /// No description provided for @inputMonitoringDescription.
  ///
  /// In en, this message translates to:
  /// **'The Fn global hotkey requires enabling VoiceType in \"System Settings > Privacy & Security > Input Monitoring\".'**
  String get inputMonitoringDescription;

  /// No description provided for @accessibilityRequired.
  ///
  /// In en, this message translates to:
  /// **'Accessibility Permission Required'**
  String get accessibilityRequired;

  /// No description provided for @accessibilityDescription.
  ///
  /// In en, this message translates to:
  /// **'To enable automatic text input, VoiceType needs to be enabled in \"System Settings > Privacy & Security > Accessibility\".'**
  String get accessibilityDescription;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @pleaseConfigureSttModel.
  ///
  /// In en, this message translates to:
  /// **'Please configure a speech recognition model first'**
  String get pleaseConfigureSttModel;

  /// No description provided for @overlayStarting.
  ///
  /// In en, this message translates to:
  /// **'Mic starting'**
  String get overlayStarting;

  /// No description provided for @overlayRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get overlayRecording;

  /// No description provided for @overlayTranscribing.
  ///
  /// In en, this message translates to:
  /// **'Transcribing'**
  String get overlayTranscribing;

  /// No description provided for @overlayEnhancing.
  ///
  /// In en, this message translates to:
  /// **'Enhancing'**
  String get overlayEnhancing;

  /// No description provided for @overlayTranscribeFailed.
  ///
  /// In en, this message translates to:
  /// **'Transcribe failed'**
  String get overlayTranscribeFailed;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the appearance theme for the application.'**
  String get themeDescription;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get themeMode;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @totalTranscriptions.
  ///
  /// In en, this message translates to:
  /// **'Total Transcriptions'**
  String get totalTranscriptions;

  /// No description provided for @totalRecordingTime.
  ///
  /// In en, this message translates to:
  /// **'Total Recording Time'**
  String get totalRecordingTime;

  /// No description provided for @totalCharacters.
  ///
  /// In en, this message translates to:
  /// **'Total Characters'**
  String get totalCharacters;

  /// No description provided for @avgCharsPerSession.
  ///
  /// In en, this message translates to:
  /// **'Avg Chars/Session'**
  String get avgCharsPerSession;

  /// No description provided for @avgRecordingDuration.
  ///
  /// In en, this message translates to:
  /// **'Avg Duration'**
  String get avgRecordingDuration;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeek;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonth;

  /// No description provided for @transcriptionCount.
  ///
  /// In en, this message translates to:
  /// **'Transcriptions'**
  String get transcriptionCount;

  /// No description provided for @recordingTime.
  ///
  /// In en, this message translates to:
  /// **'Recording Time'**
  String get recordingTime;

  /// No description provided for @characters.
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get characters;

  /// No description provided for @usageTrend.
  ///
  /// In en, this message translates to:
  /// **'Usage Trend'**
  String get usageTrend;

  /// No description provided for @providerDistribution.
  ///
  /// In en, this message translates to:
  /// **'Provider Distribution'**
  String get providerDistribution;

  /// No description provided for @modelDistribution.
  ///
  /// In en, this message translates to:
  /// **'Model Distribution'**
  String get modelDistribution;

  /// No description provided for @currentStreak.
  ///
  /// In en, this message translates to:
  /// **'Current Streak'**
  String get currentStreak;

  /// No description provided for @streakDays.
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String streakDays(int count);

  /// No description provided for @lastUsed.
  ///
  /// In en, this message translates to:
  /// **'Last Used'**
  String get lastUsed;

  /// No description provided for @mostActiveDay.
  ///
  /// In en, this message translates to:
  /// **'Most Active Day'**
  String get mostActiveDay;

  /// No description provided for @charsPerMinute.
  ///
  /// In en, this message translates to:
  /// **'Chars/Minute'**
  String get charsPerMinute;

  /// No description provided for @efficiency.
  ///
  /// In en, this message translates to:
  /// **'Efficiency'**
  String get efficiency;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @noDataYet.
  ///
  /// In en, this message translates to:
  /// **'No data yet. Start transcribing!'**
  String get noDataYet;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// No description provided for @week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get week;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @timeAgo.
  ///
  /// In en, this message translates to:
  /// **'{time} ago'**
  String timeAgo(String time);

  /// No description provided for @minuteShort.
  ///
  /// In en, this message translates to:
  /// **'m'**
  String get minuteShort;

  /// No description provided for @hourShort.
  ///
  /// In en, this message translates to:
  /// **'h'**
  String get hourShort;

  /// No description provided for @secondShort.
  ///
  /// In en, this message translates to:
  /// **'s'**
  String get secondShort;

  /// No description provided for @sessions.
  ///
  /// In en, this message translates to:
  /// **'{count} sessions'**
  String sessions(int count);

  /// No description provided for @enhanceTokenUsage.
  ///
  /// In en, this message translates to:
  /// **'Voice Input Tokens'**
  String get enhanceTokenUsage;

  /// No description provided for @enhanceInputTokens.
  ///
  /// In en, this message translates to:
  /// **'Input Tokens'**
  String get enhanceInputTokens;

  /// No description provided for @enhanceOutputTokens.
  ///
  /// In en, this message translates to:
  /// **'Output Tokens'**
  String get enhanceOutputTokens;

  /// No description provided for @enhanceTotalTokens.
  ///
  /// In en, this message translates to:
  /// **'Total Tokens'**
  String get enhanceTotalTokens;

  /// No description provided for @meetingTokenUsage.
  ///
  /// In en, this message translates to:
  /// **'Meeting Recording Tokens'**
  String get meetingTokenUsage;

  /// No description provided for @allTokenUsage.
  ///
  /// In en, this message translates to:
  /// **'All Tokens Summary'**
  String get allTokenUsage;

  /// No description provided for @showInDock.
  ///
  /// In en, this message translates to:
  /// **'Show in Dock'**
  String get showInDock;

  /// No description provided for @showInDockDescription.
  ///
  /// In en, this message translates to:
  /// **'Show the application icon in the macOS Dock.'**
  String get showInDockDescription;

  /// No description provided for @showInDockFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to change Dock visibility'**
  String get showInDockFailed;

  /// No description provided for @trayOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get trayOpen;

  /// No description provided for @trayQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get trayQuit;

  /// No description provided for @recordingPathCopied.
  ///
  /// In en, this message translates to:
  /// **'Recording path copied to clipboard'**
  String get recordingPathCopied;

  /// No description provided for @openFolderFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to open folder'**
  String get openFolderFailed;

  /// No description provided for @cleanupFailed.
  ///
  /// In en, this message translates to:
  /// **'Cleanup failed'**
  String get cleanupFailed;

  /// No description provided for @resetHotkeyDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset Default ({key})'**
  String resetHotkeyDefault(Object key);

  /// No description provided for @vadTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Silence Detection'**
  String get vadTitle;

  /// No description provided for @vadDescription.
  ///
  /// In en, this message translates to:
  /// **'Automatically detect silence during recording and stop recording after the set duration.'**
  String get vadDescription;

  /// No description provided for @vadEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable Smart Silence Detection'**
  String get vadEnable;

  /// No description provided for @vadSilenceThreshold.
  ///
  /// In en, this message translates to:
  /// **'Silence Threshold'**
  String get vadSilenceThreshold;

  /// No description provided for @vadSilenceDuration.
  ///
  /// In en, this message translates to:
  /// **'Silence Wait Duration'**
  String get vadSilenceDuration;

  /// No description provided for @sceneModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Scene Mode'**
  String get sceneModeTitle;

  /// No description provided for @sceneModeDescription.
  ///
  /// In en, this message translates to:
  /// **'Select the current scene. AI will adjust text formatting style accordingly.'**
  String get sceneModeDescription;

  /// No description provided for @sceneModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Current Scene'**
  String get sceneModeLabel;

  /// No description provided for @promptTemplates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get promptTemplates;

  /// No description provided for @promptCreateTemplate.
  ///
  /// In en, this message translates to:
  /// **'Create Template'**
  String get promptCreateTemplate;

  /// No description provided for @promptTemplateName.
  ///
  /// In en, this message translates to:
  /// **'Template Name'**
  String get promptTemplateName;

  /// No description provided for @promptTemplateContent.
  ///
  /// In en, this message translates to:
  /// **'Template Content'**
  String get promptTemplateContent;

  /// No description provided for @promptTemplateSaved.
  ///
  /// In en, this message translates to:
  /// **'Template saved'**
  String get promptTemplateSaved;

  /// No description provided for @promptBuiltin.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get promptBuiltin;

  /// No description provided for @meetingMinutes.
  ///
  /// In en, this message translates to:
  /// **'Meeting Minutes'**
  String get meetingMinutes;

  /// No description provided for @meetingNew.
  ///
  /// In en, this message translates to:
  /// **'New Meeting'**
  String get meetingNew;

  /// No description provided for @meetingRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get meetingRecording;

  /// No description provided for @meetingPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get meetingPaused;

  /// No description provided for @meetingCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get meetingCompleted;

  /// No description provided for @meetingEmpty.
  ///
  /// In en, this message translates to:
  /// **'No meeting records'**
  String get meetingEmpty;

  /// No description provided for @meetingEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Click the button above to start a new meeting recording'**
  String get meetingEmptyHint;

  /// No description provided for @meetingStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting meeting...'**
  String get meetingStarting;

  /// No description provided for @meetingTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Enter meeting title...'**
  String get meetingTitleHint;

  /// No description provided for @meetingPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get meetingPause;

  /// No description provided for @meetingResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get meetingResume;

  /// No description provided for @meetingStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get meetingStop;

  /// No description provided for @meetingListening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get meetingListening;

  /// No description provided for @meetingListeningHint.
  ///
  /// In en, this message translates to:
  /// **'Audio will be automatically segmented and transcribed'**
  String get meetingListeningHint;

  /// No description provided for @meetingTranscribing.
  ///
  /// In en, this message translates to:
  /// **'Transcribing'**
  String get meetingTranscribing;

  /// No description provided for @meetingEnhancing.
  ///
  /// In en, this message translates to:
  /// **'Enhancing text'**
  String get meetingEnhancing;

  /// No description provided for @meetingWaitingProcess.
  ///
  /// In en, this message translates to:
  /// **'Waiting to process'**
  String get meetingWaitingProcess;

  /// No description provided for @meetingPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get meetingPending;

  /// No description provided for @meetingDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get meetingDone;

  /// No description provided for @meetingError.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get meetingError;

  /// No description provided for @meetingSegmentError.
  ///
  /// In en, this message translates to:
  /// **'Processing failed'**
  String get meetingSegmentError;

  /// No description provided for @meetingRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get meetingRetry;

  /// No description provided for @meetingNoContent.
  ///
  /// In en, this message translates to:
  /// **'No transcription content'**
  String get meetingNoContent;

  /// No description provided for @meetingProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing remaining segments...'**
  String get meetingProcessing;

  /// No description provided for @meetingSegments.
  ///
  /// In en, this message translates to:
  /// **'Segments'**
  String get meetingSegments;

  /// No description provided for @meetingLongPressToEnd.
  ///
  /// In en, this message translates to:
  /// **'Long press to end meeting'**
  String get meetingLongPressToEnd;

  /// No description provided for @meetingEndingConfirm.
  ///
  /// In en, this message translates to:
  /// **'Ending meeting...'**
  String get meetingEndingConfirm;

  /// No description provided for @meetingRecordingSegment.
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get meetingRecordingSegment;

  /// No description provided for @meetingFullTranscription.
  ///
  /// In en, this message translates to:
  /// **'Meeting Minutes'**
  String get meetingFullTranscription;

  /// No description provided for @meetingStopConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'End Meeting'**
  String get meetingStopConfirmTitle;

  /// No description provided for @meetingStopConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to end the current meeting recording? All recorded segments will be processed first.'**
  String get meetingStopConfirm;

  /// No description provided for @meetingCancelConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel Meeting'**
  String get meetingCancelConfirmTitle;

  /// No description provided for @meetingCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel and discard the current meeting? This action cannot be undone.'**
  String get meetingCancelConfirm;

  /// No description provided for @meetingDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Meeting'**
  String get meetingDeleteConfirmTitle;

  /// No description provided for @meetingDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this meeting record? This action cannot be undone.'**
  String get meetingDeleteConfirm;

  /// No description provided for @meetingDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get meetingDate;

  /// No description provided for @meetingDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get meetingDuration;

  /// No description provided for @meetingTotalChars.
  ///
  /// In en, this message translates to:
  /// **'Total Characters'**
  String get meetingTotalChars;

  /// No description provided for @meetingTitle.
  ///
  /// In en, this message translates to:
  /// **'Meeting Title'**
  String get meetingTitle;

  /// No description provided for @meetingSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get meetingSaved;

  /// No description provided for @meetingSummary.
  ///
  /// In en, this message translates to:
  /// **'Meeting Summary'**
  String get meetingSummary;

  /// No description provided for @meetingContent.
  ///
  /// In en, this message translates to:
  /// **'Meeting Content'**
  String get meetingContent;

  /// No description provided for @meetingCopyAll.
  ///
  /// In en, this message translates to:
  /// **'Copy All'**
  String get meetingCopyAll;

  /// No description provided for @meetingExportText.
  ///
  /// In en, this message translates to:
  /// **'Export as Text'**
  String get meetingExportText;

  /// No description provided for @meetingExportMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Export as Markdown'**
  String get meetingExportMarkdown;

  /// No description provided for @meetingExported.
  ///
  /// In en, this message translates to:
  /// **'Exported to clipboard'**
  String get meetingExported;

  /// No description provided for @meetingEmptyContent.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get meetingEmptyContent;

  /// No description provided for @meetingNotFound.
  ///
  /// In en, this message translates to:
  /// **'Meeting record not found'**
  String get meetingNotFound;

  /// No description provided for @meetingOverlayStarting.
  ///
  /// In en, this message translates to:
  /// **'Meeting starting'**
  String get meetingOverlayStarting;

  /// No description provided for @meetingOverlayRecording.
  ///
  /// In en, this message translates to:
  /// **'Meeting recording'**
  String get meetingOverlayRecording;

  /// No description provided for @meetingOverlayPaused.
  ///
  /// In en, this message translates to:
  /// **'Meeting paused'**
  String get meetingOverlayPaused;

  /// No description provided for @meetingOverlayProcessing.
  ///
  /// In en, this message translates to:
  /// **'Meeting processing'**
  String get meetingOverlayProcessing;
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
