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
  String get promptWorkshop => 'Prompt Settings';

  @override
  String get aiEnhanceHub => 'AI Enhancement';

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
  String get meetingHotkey => 'Meeting Recording Hotkey';

  @override
  String get meetingHotkeyDescription =>
      'Configure the hotkey for starting and ending meeting recording. Press once to start, press again to end.';

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
  String get recordingStorage => 'Recording Storage';

  @override
  String get recordingStorageDescription =>
      'View and manage recording audio files.';

  @override
  String get recordingFiles => 'Recording Files';

  @override
  String get files => 'files';

  @override
  String get openRecordingFolder => 'Open Folder';

  @override
  String get copyPath => 'Copy Path';

  @override
  String get clearRecordingFiles => 'Clear Files';

  @override
  String get clearRecordingFilesConfirm =>
      'Are you sure you want to delete all recording files? This action cannot be undone.';

  @override
  String get confirm => 'Confirm';

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

  @override
  String get networkSettings => 'Network';

  @override
  String get networkSettingsDescription =>
      'Configure the network proxy mode for the application.';

  @override
  String get systemSettings => 'System';

  @override
  String get systemSettingsDescription =>
      'Configure system-level settings such as startup behavior and network proxy.';

  @override
  String get launchAtLogin => 'Launch at Login';

  @override
  String get launchAtLoginDescription =>
      'Automatically start VoiceType when you log in.';

  @override
  String get launchAtLoginFailed => 'Failed to enable launch at login';

  @override
  String get disableLaunchAtLoginFailed => 'Failed to disable launch at login';

  @override
  String get proxyConfig => 'Proxy Configuration';

  @override
  String get useSystemProxy => 'Use System Proxy';

  @override
  String get systemProxySubtitle =>
      'Requests follow the system network proxy configuration.';

  @override
  String get noProxy => 'No Proxy';

  @override
  String get noProxySubtitle =>
      'All requests connect directly without any proxy.';

  @override
  String get inputMonitoringRequired => 'Input Monitoring Required';

  @override
  String get inputMonitoringDescription =>
      'The Fn global hotkey requires enabling VoiceType in \"System Settings > Privacy & Security > Input Monitoring\".';

  @override
  String get accessibilityRequired => 'Accessibility Permission Required';

  @override
  String get accessibilityDescription =>
      'To enable automatic text input, VoiceType needs to be enabled in \"System Settings > Privacy & Security > Accessibility\".';

  @override
  String get later => 'Later';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get pleaseConfigureSttModel =>
      'Please configure a speech recognition model first';

  @override
  String get overlayStarting => 'Mic starting';

  @override
  String get overlayRecording => 'Recording';

  @override
  String get overlayTranscribing => 'Transcribing';

  @override
  String get overlayEnhancing => 'Enhancing';

  @override
  String get overlayTranscribeFailed => 'Transcribe failed';

  @override
  String get theme => 'Theme';

  @override
  String get themeDescription =>
      'Choose the appearance theme for the application.';

  @override
  String get themeMode => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get totalTranscriptions => 'Total Transcriptions';

  @override
  String get totalRecordingTime => 'Total Recording Time';

  @override
  String get totalCharacters => 'Total Characters';

  @override
  String get avgCharsPerSession => 'Avg Chars/Session';

  @override
  String get avgRecordingDuration => 'Avg Duration';

  @override
  String get today => 'Today';

  @override
  String get thisWeek => 'This Week';

  @override
  String get thisMonth => 'This Month';

  @override
  String get transcriptionCount => 'Transcriptions';

  @override
  String get recordingTime => 'Recording Time';

  @override
  String get characters => 'Characters';

  @override
  String get usageTrend => 'Usage Trend';

  @override
  String get providerDistribution => 'Provider Distribution';

  @override
  String get modelDistribution => 'Model Distribution';

  @override
  String get currentStreak => 'Current Streak';

  @override
  String streakDays(int count) {
    return '$count days';
  }

  @override
  String get lastUsed => 'Last Used';

  @override
  String get mostActiveDay => 'Most Active Day';

  @override
  String get charsPerMinute => 'Chars/Minute';

  @override
  String get efficiency => 'Efficiency';

  @override
  String get activity => 'Activity';

  @override
  String get noDataYet => 'No data yet. Start transcribing!';

  @override
  String get day => 'Day';

  @override
  String get week => 'Week';

  @override
  String get month => 'Month';

  @override
  String timeAgo(String time) {
    return '$time ago';
  }

  @override
  String get minuteShort => 'm';

  @override
  String get hourShort => 'h';

  @override
  String get secondShort => 's';

  @override
  String sessions(int count) {
    return '$count sessions';
  }

  @override
  String get enhanceTokenUsage => 'Voice Input Tokens';

  @override
  String get enhanceInputTokens => 'Input Tokens';

  @override
  String get enhanceOutputTokens => 'Output Tokens';

  @override
  String get enhanceTotalTokens => 'Total Tokens';

  @override
  String get meetingTokenUsage => 'Meeting Recording Tokens';

  @override
  String get allTokenUsage => 'All Tokens Summary';

  @override
  String get showInDock => 'Show in Dock';

  @override
  String get showInDockDescription =>
      'Show the application icon in the macOS Dock.';

  @override
  String get showInDockFailed => 'Failed to change Dock visibility';

  @override
  String get trayOpen => 'Open';

  @override
  String get trayQuit => 'Quit';

  @override
  String get recordingPathCopied => 'Recording path copied to clipboard';

  @override
  String get openFolderFailed => 'Failed to open folder';

  @override
  String get cleanupFailed => 'Cleanup failed';

  @override
  String resetHotkeyDefault(Object key) {
    return 'Reset Default ($key)';
  }

  @override
  String get vadTitle => 'Smart Silence Detection';

  @override
  String get vadDescription =>
      'Automatically detect silence during recording and stop recording after the set duration.';

  @override
  String get vadEnable => 'Enable Smart Silence Detection';

  @override
  String get vadSilenceThreshold => 'Silence Threshold';

  @override
  String get vadSilenceDuration => 'Silence Wait Duration';

  @override
  String get sceneModeTitle => 'Scene Mode';

  @override
  String get sceneModeDescription =>
      'Select the current scene. AI will adjust text formatting style accordingly.';

  @override
  String get sceneModeLabel => 'Current Scene';

  @override
  String get promptTemplates => 'Templates';

  @override
  String get promptCreateTemplate => 'Create Template';

  @override
  String get promptTemplateName => 'Template Name';

  @override
  String get promptTemplateContent => 'Template Content';

  @override
  String get promptTemplateSaved => 'Template saved';

  @override
  String get promptBuiltin => 'Built-in';

  @override
  String get promptSelectHint =>
      'Select a template from the list to view details';

  @override
  String get promptPreview => 'Preview';

  @override
  String get dictionarySettings => 'Dictionary';

  @override
  String get dictionaryDescription =>
      'Save commonly used words and phrases. The AI will prioritize using dictionary entries for more accurate output.';

  @override
  String get dictionaryAdd => 'Add Word';

  @override
  String get dictionaryEdit => 'Edit Word';

  @override
  String get dictionaryWord => 'Word';

  @override
  String get dictionaryWordHint =>
      'Enter a commonly used word, e.g., technical terms, names';

  @override
  String get dictionaryWordDescription => 'Description (optional)';

  @override
  String get dictionaryWordDescriptionHint =>
      'Brief description of the word\'s meaning or usage context';

  @override
  String get dictionaryEmpty => 'Dictionary is empty';

  @override
  String get dictionaryEmptyHint =>
      'Add commonly used words to help AI produce better output';

  @override
  String get meetingMinutes => 'Meeting Minutes';

  @override
  String get meetingNew => 'New Meeting';

  @override
  String get meetingRecording => 'Recording';

  @override
  String get meetingPaused => 'Paused';

  @override
  String get meetingCompleted => 'Completed';

  @override
  String get meetingEmpty => 'No meeting records';

  @override
  String get meetingEmptyHint =>
      'Click the button above to start a new meeting recording';

  @override
  String get meetingStarting => 'Starting meeting...';

  @override
  String get meetingTitleHint => 'Enter meeting title...';

  @override
  String get meetingPause => 'Pause';

  @override
  String get meetingResume => 'Resume';

  @override
  String get meetingStop => 'Stop';

  @override
  String get meetingListening => 'Listening...';

  @override
  String get meetingListeningHint =>
      'Audio will be automatically segmented and transcribed';

  @override
  String get meetingTranscribing => 'Transcribing';

  @override
  String get meetingEnhancing => 'Enhancing text';

  @override
  String get meetingWaitingProcess => 'Waiting to process';

  @override
  String get meetingPending => 'Pending';

  @override
  String get meetingDone => 'Done';

  @override
  String get meetingError => 'Failed';

  @override
  String get meetingSegmentError => 'Processing failed';

  @override
  String get meetingRetry => 'Retry';

  @override
  String get meetingNoContent => 'No transcription content';

  @override
  String get meetingProcessing => 'Processing remaining segments...';

  @override
  String get meetingSegments => 'Segments';

  @override
  String get meetingLongPressToEnd => 'Long press to end meeting';

  @override
  String get meetingEndingConfirm => 'Ending meeting...';

  @override
  String get meetingRecordingSegment => 'Recording...';

  @override
  String get meetingFullTranscription => 'Meeting Minutes';

  @override
  String get meetingStopConfirmTitle => 'End Meeting';

  @override
  String get meetingStopConfirm =>
      'Are you sure you want to end the current meeting recording? All recorded segments will be processed first.';

  @override
  String get meetingCancelConfirmTitle => 'Cancel Meeting';

  @override
  String get meetingCancelConfirm =>
      'Are you sure you want to cancel and discard the current meeting? This action cannot be undone.';

  @override
  String get meetingDeleteConfirmTitle => 'Delete Meeting';

  @override
  String get meetingDeleteConfirm =>
      'Are you sure you want to delete this meeting record? This action cannot be undone.';

  @override
  String get meetingDate => 'Date';

  @override
  String get meetingDuration => 'Duration';

  @override
  String get meetingTotalChars => 'Total Characters';

  @override
  String get meetingTitle => 'Meeting Title';

  @override
  String get meetingSaved => 'Saved';

  @override
  String get meetingSummary => 'Meeting Summary';

  @override
  String get meetingContent => 'Meeting Content';

  @override
  String get meetingCopyAll => 'Copy All';

  @override
  String get meetingExportText => 'Export as Text';

  @override
  String get meetingExportMarkdown => 'Export as Markdown';

  @override
  String get meetingExported => 'Exported to clipboard';

  @override
  String get meetingEmptyContent => 'Empty';

  @override
  String get meetingNotFound => 'Meeting record not found';

  @override
  String get meetingOverlayStarting => 'Meeting starting';

  @override
  String get meetingOverlayRecording => 'Meeting recording';

  @override
  String get meetingOverlayPaused => 'Meeting paused';

  @override
  String get meetingOverlayProcessing => 'Meeting processing';

  @override
  String get meetingRecordingBanner => 'Meeting recording in progress';

  @override
  String get meetingReturnToRecording => 'Return to recording';

  @override
  String get meetingSegmentView => 'Segments';

  @override
  String get meetingMergedNoteView => 'Merged Notes';

  @override
  String get meetingStreamingMerge => 'Merging...';

  @override
  String get meetingDetailTab => 'Meeting Details';

  @override
  String get meetingSummaryTab => 'Meeting Summary';

  @override
  String get meetingGeneratingSummary => 'Generating meeting summary...';

  @override
  String get meetingNoSummary => 'No meeting summary yet';

  @override
  String get meetingRegenerateSummary => 'Regenerate';

  @override
  String get addToDictionary => 'Add to Dictionary';

  @override
  String get addedToDictionary => 'Added to dictionary';
}
