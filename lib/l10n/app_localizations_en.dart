// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'VoiceType';

  @override
  String get loading => 'Loading...';

  @override
  String get generalSettings => 'General';

  @override
  String get voiceModelSettings => 'Voice Model';

  @override
  String get textModelSettings => 'Text Model';

  @override
  String get promptWorkshop => 'Prompt Workshop';

  @override
  String get history => 'History';

  @override
  String get logs => 'Logs';

  @override
  String get about => 'About';

  @override
  String get activationMode => 'Activation Mode';

  @override
  String get tapToTalk => 'Tap Mode';

  @override
  String get tapToTalkSubtitle => 'Tap to start, tap to stop';

  @override
  String get tapToTalkDescription =>
      'Press hotkey to start recording, press again to stop';

  @override
  String get pushToTalk => 'Hold Mode';

  @override
  String get pushToTalkSubtitle => 'Hold to record, release to stop';

  @override
  String get pushToTalkDescription => 'Hold hotkey to record, release to stop';

  @override
  String get dictationHotkey => 'Dictation Hotkey';

  @override
  String get dictationHotkeyDescription =>
      'Configure the hotkey for starting and stopping voice dictation.';

  @override
  String get pressKeyToSet => 'Press a key to set as hotkey';

  @override
  String get clickToChangeHotkey => 'Click to change hotkey';

  @override
  String get resetToDefault => 'Reset to Default';

  @override
  String get permissions => 'Permissions';

  @override
  String get permissionsDescription =>
      'Manage system permissions for optimal performance.';

  @override
  String get microphonePermission => 'Microphone Permission';

  @override
  String get accessibilityPermission => 'Accessibility Permission';

  @override
  String get testPermission => 'Test';

  @override
  String get permissionGranted => 'Granted';

  @override
  String get permissionDenied => 'Denied';

  @override
  String get permissionHint =>
      'Microphone permission is required for voice input. Accessibility permission is needed for text insertion.';

  @override
  String get testMicrophonePermission => 'Test Microphone Permission';

  @override
  String get testAccessibilityPermission => 'Test Accessibility Permission';

  @override
  String get fixPermissionIssues => 'Fix Permission Issues';

  @override
  String get openSoundInput => 'Open Sound Input';

  @override
  String get openMicrophonePrivacy => 'Open Microphone Privacy';

  @override
  String get openAccessibilityPrivacy => 'Open Accessibility Privacy';

  @override
  String get microphoneInput => 'Microphone Input';

  @override
  String get microphoneInputDescription =>
      'Select the microphone for dictation. Enable \'Prefer Built-in Microphone\' to prevent audio interruptions when using Bluetooth headphones.';

  @override
  String get preferBuiltInMicrophone => 'Prefer Built-in Microphone';

  @override
  String get preferBuiltInMicrophoneSubtitle =>
      'External microphones may cause latency or reduce transcription quality';

  @override
  String get currentDevice => 'Current Device';

  @override
  String get unknownDevice => 'Unknown Device';

  @override
  String get noMicrophoneDetected => 'No microphone detected';

  @override
  String get using => 'Using';

  @override
  String get minRecordingDuration => 'Minimum Recording Duration';

  @override
  String get minRecordingDurationDescription =>
      'Recordings shorter than this duration will be automatically ignored to avoid accidental triggers.';

  @override
  String get ignoreShortRecordings => 'Ignore recordings shorter than';

  @override
  String get seconds => 'seconds';

  @override
  String get language => 'Language';

  @override
  String get languageDescription => 'Select your preferred interface language.';

  @override
  String get interfaceLanguage => 'Interface Language';

  @override
  String get english => 'English';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get logsDescription => 'View and manage application log files.';

  @override
  String get logFile => 'Log File';

  @override
  String get noLogFile => 'No Log File';

  @override
  String get openLogDirectory => 'Open Log Directory';

  @override
  String get copyLogPath => 'Copy Path';

  @override
  String get logPathCopied => 'Log path copied to clipboard';

  @override
  String get tip => 'Tip';

  @override
  String get logsTip =>
      'Log files contain application runtime records for troubleshooting. If the app encounters issues, you can provide this log file to developers for analysis.';

  @override
  String get addModel => 'Add Model';

  @override
  String get addVoiceModel => 'Add Voice Model';

  @override
  String get addTextModel => 'Add Text Model';

  @override
  String get editModel => 'Edit Model';

  @override
  String get editVoiceModel => 'Edit Voice Model';

  @override
  String get editTextModel => 'Edit Text Model';

  @override
  String get deleteModel => 'Delete Model';

  @override
  String deleteModelConfirm(Object model, Object vendor) {
    return 'Are you sure you want to delete $vendor / $model?';
  }

  @override
  String confirmDeleteModel(String vendor, String model) {
    return 'Are you sure you want to delete $vendor / $model?';
  }

  @override
  String get vendor => 'Vendor';

  @override
  String get model => 'Model';

  @override
  String get endpointUrl => 'Endpoint URL';

  @override
  String get apiKey => 'API Key';

  @override
  String get selectVendor => 'Select Vendor';

  @override
  String get selectModel => 'Select Model';

  @override
  String get custom => 'Custom';

  @override
  String enterModelName(Object example) {
    return 'Enter model name, e.g., $example';
  }

  @override
  String get enterApiKey => 'Enter API Key';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get testConnection => 'Test Connection';

  @override
  String get testingConnection => 'Testing connection...';

  @override
  String get connectionSuccess => 'Connection successful ✓';

  @override
  String get connectionFailed =>
      'Connection failed, please check configuration';

  @override
  String get inUse => 'In Use';

  @override
  String get useThisModel => 'Use This Model';

  @override
  String get currentlyInUse => 'Currently in use';

  @override
  String get noModelsAdded => 'No models added yet';

  @override
  String get addVoiceModelHint =>
      'Click the button below to add a speech recognition model';

  @override
  String get addTextModelHint =>
      'Click the button below to add a large language model';

  @override
  String get enableTextEnhancement => 'Enable Text Enhancement';

  @override
  String get textEnhancementDescription =>
      'Use AI to enhance and correct transcribed text.';

  @override
  String get prompt => 'Prompt';

  @override
  String get promptDescription =>
      'Customize the AI behavior for text enhancement.';

  @override
  String get defaultPrompt => 'Default Prompt';

  @override
  String get customPrompt => 'Custom Prompt';

  @override
  String get useCustomPrompt => 'Use Custom Prompt';

  @override
  String get agentName => 'Agent Name';

  @override
  String get enterAgentName => 'Enter agent name';

  @override
  String get current => 'Current';

  @override
  String get test => 'Test';

  @override
  String get currentSystemPrompt => 'Current System Prompt';

  @override
  String get customPromptTitle => 'Custom Prompt';

  @override
  String get enableCustomPrompt => 'Enable Custom Prompt';

  @override
  String get customPromptEnabled =>
      'Enabled: Text enhancement will use custom prompt below';

  @override
  String get customPromptDisabled =>
      'Disabled: Text enhancement will use system default prompt';

  @override
  String agentNamePlaceholder(Object agentName) {
    return 'Use $agentName as placeholder for agent name';
  }

  @override
  String get systemPrompt => 'System Prompt';

  @override
  String get saveAgentConfig => 'Save Agent Configuration';

  @override
  String get restoreDefault => 'Restore Default';

  @override
  String get testYourAgent => 'Test Your Agent';

  @override
  String get testAgentDescription =>
      'Test with current text model and agent prompt.';

  @override
  String get testInput => 'Test Input';

  @override
  String get enterTestText => 'Enter text to polish...';

  @override
  String get running => 'Running...';

  @override
  String get runTest => 'Run Test';

  @override
  String get outputResult => 'Output Result';

  @override
  String get outputWillAppearHere => 'Output will appear here';

  @override
  String get historySection => 'History';

  @override
  String get noHistory => 'No transcription history';

  @override
  String get historyHint =>
      'Use hotkey to start recording, transcription results will appear here';

  @override
  String get clearHistory => 'Clear History';

  @override
  String get clearHistoryConfirm =>
      'Are you sure you want to clear all history? This action cannot be undone.';

  @override
  String get clearAll => 'Clear All';

  @override
  String get clear => 'Clear';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get deleteHistoryItem => 'Delete';

  @override
  String get searchHistory => 'Search history...';

  @override
  String get aboutSection => 'About';

  @override
  String get appDescription =>
      'A voice input tool that supports multiple cloud LLMs and local Whisper models, converting speech to text quickly.';

  @override
  String get version => 'Version';

  @override
  String get checkForUpdates => 'Check for Updates';

  @override
  String get openSourceLicenses => 'Open Source Licenses';

  @override
  String get required => 'Required';

  @override
  String get optional => 'Optional';
}
