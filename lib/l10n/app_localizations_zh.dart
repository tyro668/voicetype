// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '释手';

  @override
  String get loading => '加载中...';

  @override
  String get generalSettings => '通用设置';

  @override
  String get voiceModelSettings => '语音模型';

  @override
  String get textModelSettings => '文本模型';

  @override
  String get promptWorkshop => '提示词设置';

  @override
  String get aiEnhanceHub => '智能增强';

  @override
  String get history => '历史记录';

  @override
  String get logs => '日志';

  @override
  String get about => '关于';

  @override
  String get activationMode => '激活模式';

  @override
  String get tapToTalk => '点击模式';

  @override
  String get tapToTalkSubtitle => '点击开始，点击停止';

  @override
  String get tapToTalkDescription => '按快捷键开始录音，再次按下停止录音';

  @override
  String get pushToTalk => '按住模式';

  @override
  String get pushToTalkSubtitle => '按住录音，松开停止';

  @override
  String get pushToTalkDescription => '按住快捷键录音，松开停止录音';

  @override
  String get dictationHotkey => '听写快捷键';

  @override
  String get dictationHotkeyDescription => '配置用于开始和停止语音听写的按键。';

  @override
  String get meetingHotkey => '会议录音快捷键';

  @override
  String get meetingHotkeyDescription => '配置用于开始和结束会议录音的按键。按一次开始录音，再按一次结束。';

  @override
  String get pressKeyToSet => '按下要设置为快捷键的按键';

  @override
  String get clickToChangeHotkey => '点击更改快捷键';

  @override
  String get resetToDefault => '恢复默认';

  @override
  String get permissions => '权限设置';

  @override
  String get permissionsDescription => '管理系统权限以获取最佳性能功能。';

  @override
  String get microphonePermission => '麦克风权限';

  @override
  String get accessibilityPermission => '辅助功能权限';

  @override
  String get testPermission => '测试';

  @override
  String get permissionGranted => '已授权';

  @override
  String get permissionDenied => '未授权';

  @override
  String get permissionHint => '麦克风权限用于语音输入，辅助功能权限用于文本插入。';

  @override
  String get testMicrophonePermission => '测试麦克风权限';

  @override
  String get testAccessibilityPermission => '测试辅助功能权限';

  @override
  String get fixPermissionIssues => '修复权限问题';

  @override
  String get openSoundInput => '打开声音输入';

  @override
  String get openMicrophonePrivacy => '打开麦克风隐私';

  @override
  String get openAccessibilityPrivacy => '打开辅助功能隐私';

  @override
  String get microphoneInput => '麦克风输入';

  @override
  String get microphoneInputDescription =>
      '选择用于听写的麦克风。启用「优先使用内置麦克风」可防止使用蓝牙耳机时音频中断。';

  @override
  String get preferBuiltInMicrophone => '优先使用内置麦克风';

  @override
  String get preferBuiltInMicrophoneSubtitle => '外置麦克风可能导致延迟或降低转录质量';

  @override
  String get currentDevice => '当前设备';

  @override
  String get unknownDevice => '未知设备';

  @override
  String get noMicrophoneDetected => '未检测到麦克风';

  @override
  String get using => '正在使用';

  @override
  String get minRecordingDuration => '最短录音时长';

  @override
  String get minRecordingDurationDescription => '录音时长低于此值时将自动忽略，避免误触产生无效输入。';

  @override
  String get ignoreShortRecordings => '忽略短于此时长的录音';

  @override
  String get seconds => '秒';

  @override
  String get language => '语言';

  @override
  String get languageDescription => '选择您偏好的界面语言。';

  @override
  String get interfaceLanguage => '界面语言';

  @override
  String get english => 'English';

  @override
  String get simplifiedChinese => '简体中文';

  @override
  String get logsDescription => '查看和管理应用程序日志文件。';

  @override
  String get logFile => '日志文件';

  @override
  String get noLogFile => '无日志文件';

  @override
  String get openLogDirectory => '打开日志文件夹';

  @override
  String get copyLogPath => '复制路径';

  @override
  String get logPathCopied => '日志路径已复制到剪贴板';

  @override
  String get tip => '提示';

  @override
  String get logsTip => '日志文件包含应用程序的运行记录，可用于排查问题。如果应用出现异常，可以将此日志文件提供给开发者进行分析。';

  @override
  String get recordingStorage => '录音文件存储';

  @override
  String get recordingStorageDescription => '查看和管理录音音频文件的存储位置。';

  @override
  String get recordingFiles => '录音文件';

  @override
  String get files => '个文件';

  @override
  String get openRecordingFolder => '打开文件夹';

  @override
  String get copyPath => '复制路径';

  @override
  String get clearRecordingFiles => '清理文件';

  @override
  String get clearRecordingFilesConfirm => '确定要删除所有录音文件吗？此操作不可撤销。';

  @override
  String get confirm => '确定';

  @override
  String get addModel => '添加模型';

  @override
  String get addVoiceModel => '添加语音模型';

  @override
  String get addTextModel => '添加文本模型';

  @override
  String get editModel => '编辑模型';

  @override
  String get editVoiceModel => '编辑语音模型';

  @override
  String get editTextModel => '编辑文本模型';

  @override
  String get deleteModel => '删除模型';

  @override
  String deleteModelConfirm(Object model, Object vendor) {
    return '确定要删除 $vendor / $model 吗？';
  }

  @override
  String confirmDeleteModel(String vendor, String model) {
    return '确定要删除 $vendor / $model 吗？';
  }

  @override
  String get vendor => '服务商';

  @override
  String get model => '模型';

  @override
  String get endpointUrl => '端点 URL';

  @override
  String get apiKey => 'API 密钥';

  @override
  String get selectVendor => '选择服务商';

  @override
  String get selectModel => '选择模型';

  @override
  String get custom => '自定义';

  @override
  String enterModelName(Object example) {
    return '输入模型名称，如 $example';
  }

  @override
  String get enterApiKey => '输入 API 密钥';

  @override
  String get saveChanges => '保存修改';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get edit => '编辑';

  @override
  String get testConnection => '测试连接';

  @override
  String get testingConnection => '正在测试连接...';

  @override
  String get connectionSuccess => '连接成功 ✓';

  @override
  String get connectionFailed => '连接失败，请检查配置';

  @override
  String get inUse => '使用中';

  @override
  String get useThisModel => '使用此模型';

  @override
  String get currentlyInUse => '当前正在使用';

  @override
  String get noModelsAdded => '暂未添加模型';

  @override
  String get addVoiceModelHint => '点击下方按钮添加一个语音识别模型';

  @override
  String get addTextModelHint => '点击下方按钮添加一个大语言模型';

  @override
  String get enableTextEnhancement => '启用文本增强';

  @override
  String get textEnhancementDescription => '使用 AI 增强和修正转录的文本。';

  @override
  String get prompt => '提示词';

  @override
  String get promptDescription => '自定义 AI 文本增强的行为。';

  @override
  String get defaultPrompt => '默认提示词';

  @override
  String get customPrompt => '自定义提示词';

  @override
  String get useCustomPrompt => '使用自定义提示词';

  @override
  String get agentName => '助手名称';

  @override
  String get enterAgentName => '输入助手名称';

  @override
  String get current => '当前';

  @override
  String get test => '测试';

  @override
  String get currentSystemPrompt => '当前系统智能体提示词';

  @override
  String get customPromptTitle => '自定义智能体提示词';

  @override
  String get enableCustomPrompt => '启用自定义提示词';

  @override
  String get customPromptEnabled => '已启用：文本整理将使用下方自定义提示词';

  @override
  String get customPromptDisabled => '已关闭：文本整理将使用系统默认提示词';

  @override
  String agentNamePlaceholder(Object agentName) {
    return '使用 $agentName 作为智能体名称占位符';
  }

  @override
  String get systemPrompt => '系统提示词';

  @override
  String get saveAgentConfig => '保存智能体配置';

  @override
  String get restoreDefault => '恢复默认';

  @override
  String get testYourAgent => '测试您的智能体';

  @override
  String get testAgentDescription => '使用当前文本模型与智能体提示词进行测试。';

  @override
  String get testInput => '测试输入';

  @override
  String get enterTestText => '输入一段需要润色的文本...';

  @override
  String get running => '运行中...';

  @override
  String get runTest => '运行测试';

  @override
  String get outputResult => '输出结果';

  @override
  String get outputWillAppearHere => '输出结果将显示在这里';

  @override
  String get historySection => '历史记录';

  @override
  String get noHistory => '暂无转写历史';

  @override
  String get historyHint => '使用快捷键开始录音，转录结果将显示在这里';

  @override
  String get clearHistory => '清空历史记录';

  @override
  String get clearHistoryConfirm => '确定要删除所有历史记录吗？此操作不可撤销。';

  @override
  String get clearAll => '清空全部';

  @override
  String get clear => '清空';

  @override
  String get copy => '复制';

  @override
  String get copied => '已复制';

  @override
  String get copiedToClipboard => '已复制到剪贴板';

  @override
  String get deleteHistoryItem => '删除';

  @override
  String get searchHistory => '搜索历史记录...';

  @override
  String get aboutSection => '关于';

  @override
  String get appDescription => '释手是一款语音输入工具，支持多种云端大模型和本地 Whisper 模型，让所想即所写。';

  @override
  String get appSlogan => '言之所至，释手而书。';

  @override
  String get version => '版本';

  @override
  String get checkForUpdates => '检查更新';

  @override
  String get openSourceLicenses => '开源许可证';

  @override
  String get required => '必填';

  @override
  String get optional => '选填';

  @override
  String get networkSettings => '网络设置';

  @override
  String get networkSettingsDescription => '配置应用的网络代理模式。';

  @override
  String get systemSettings => '系统设置';

  @override
  String get systemSettingsDescription => '配置系统级设置，如开机启动和网络代理。';

  @override
  String get launchAtLogin => '开机启动';

  @override
  String get launchAtLoginDescription => '登录系统时自动启动 释手。';

  @override
  String get launchAtLoginFailed => '启用开机启动失败';

  @override
  String get disableLaunchAtLoginFailed => '关闭开机启动失败';

  @override
  String get proxyConfig => '代理配置';

  @override
  String get useSystemProxy => '使用系统代理';

  @override
  String get systemProxySubtitle => '请求遵循系统网络代理配置。';

  @override
  String get noProxy => '不使用代理';

  @override
  String get noProxySubtitle => '所有请求直连，不走任何代理。';

  @override
  String get inputMonitoringRequired => '需要输入监控权限';

  @override
  String get inputMonitoringDescription =>
      'Fn 全局快捷键需要在「系统设置 > 隐私与安全性 > 输入监控」中勾选 释手。';

  @override
  String get accessibilityRequired => '需要辅助功能权限';

  @override
  String get accessibilityDescription =>
      '为实现自动输入，需要在「系统设置 > 隐私与安全性 > 辅助功能」中勾选 释手。';

  @override
  String get later => '稍后';

  @override
  String get openSettings => '打开设置';

  @override
  String get pleaseConfigureSttModel => '请先配置语音转换模型';

  @override
  String get overlayStarting => '麦克风启动中';

  @override
  String get overlayRecording => '录音中';

  @override
  String get overlayTranscribing => '语音转换中';

  @override
  String get overlayEnhancing => '文字整理中';

  @override
  String get overlayTranscribeFailed => '语音转录失败';

  @override
  String get theme => '外观';

  @override
  String get themeDescription => '选择应用的外观主题。';

  @override
  String get themeMode => '外观模式';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get dashboard => '仪表盘';

  @override
  String get totalTranscriptions => '总转录次数';

  @override
  String get totalRecordingTime => '总录音时长';

  @override
  String get totalCharacters => '总字数';

  @override
  String get avgCharsPerSession => '平均每次字数';

  @override
  String get avgRecordingDuration => '平均录音时长';

  @override
  String get today => '今日';

  @override
  String get thisWeek => '本周';

  @override
  String get thisMonth => '本月';

  @override
  String get transcriptionCount => '转录次数';

  @override
  String get recordingTime => '录音时长';

  @override
  String get characters => '字数';

  @override
  String get usageTrend => '使用趋势';

  @override
  String get providerDistribution => '服务商分布';

  @override
  String get modelDistribution => '模型分布';

  @override
  String get currentStreak => '连续使用天数';

  @override
  String streakDays(int count) {
    return '$count 天';
  }

  @override
  String get lastUsed => '最近使用';

  @override
  String get mostActiveDay => '最活跃的一天';

  @override
  String get charsPerMinute => '每分钟字数';

  @override
  String get efficiency => '效率';

  @override
  String get activity => '活跃度';

  @override
  String get noDataYet => '暂无数据，开始转录吧！';

  @override
  String get day => '日';

  @override
  String get week => '周';

  @override
  String get month => '月';

  @override
  String timeAgo(String time) {
    return '$time前';
  }

  @override
  String get minuteShort => '分';

  @override
  String get hourShort => '时';

  @override
  String get secondShort => '秒';

  @override
  String sessions(int count) {
    return '$count 次';
  }

  @override
  String get enhanceTokenUsage => '语音输入 Token 用量';

  @override
  String get enhanceInputTokens => '输入 Token';

  @override
  String get enhanceOutputTokens => '输出 Token';

  @override
  String get enhanceTotalTokens => '总 Token';

  @override
  String get meetingTokenUsage => '会议记录 Token 用量';

  @override
  String get allTokenUsage => '全部 Token 汇总';

  @override
  String get showInDock => '在 Dock 中显示';

  @override
  String get showInDockDescription => '控制应用程序图标是否显示在 Dock 上。';

  @override
  String get showInDockFailed => '修改 Dock 显示状态失败';

  @override
  String get trayOpen => '打开';

  @override
  String get trayQuit => '退出';

  @override
  String get recordingPathCopied => '录音路径已复制到剪贴板';

  @override
  String get openFolderFailed => '打开文件夹失败';

  @override
  String get cleanupFailed => '清理失败';

  @override
  String resetHotkeyDefault(Object key) {
    return '恢复默认（$key）';
  }

  @override
  String get vadTitle => '智能静音检测';

  @override
  String get vadDescription => '录音时自动检测沉默，超过设定时间后自动停止录音并开始转录。';

  @override
  String get vadEnable => '启用智能静音检测';

  @override
  String get vadSilenceThreshold => '静音阈值';

  @override
  String get vadSilenceDuration => '静音等待时长';

  @override
  String get sceneModeTitle => '场景模式';

  @override
  String get sceneModeDescription => '选择当前场景，AI 将根据场景调整文本规整的风格和格式。';

  @override
  String get sceneModeLabel => '当前场景';

  @override
  String get promptTemplates => '模板列表';

  @override
  String get promptCreateTemplate => '创建模板';

  @override
  String get promptTemplateName => '模板名称';

  @override
  String get promptTemplateContent => '模板内容';

  @override
  String get promptTemplateSaved => '模板已保存';

  @override
  String get promptBuiltin => '内置';

  @override
  String get promptSelectHint => '从左侧选择一个模板查看详情';

  @override
  String get promptPreview => '预览';

  @override
  String get dictionarySettings => '词典设置';

  @override
  String get dictionaryDescription => '保存常用词语，AI 会优先使用词典中的词语来生成更准确的输出。';

  @override
  String get dictionaryAdd => '添加词语';

  @override
  String get dictionaryEdit => '编辑词语';

  @override
  String get dictionaryWord => '词语';

  @override
  String get dictionaryWordHint => '输入常用词语，如专业术语、人名等';

  @override
  String get dictionaryWordDescription => '说明（选填）';

  @override
  String get dictionaryWordDescriptionHint => '简要说明该词语的含义或使用场景';

  @override
  String get dictionaryEmpty => '词典为空';

  @override
  String get dictionaryEmptyHint => '添加常用词语，帮助 AI 更好地输出';

  @override
  String get meetingMinutes => '会议记录';

  @override
  String get meetingNew => '新建会议';

  @override
  String get meetingRecording => '录制中';

  @override
  String get meetingPaused => '已暂停';

  @override
  String get meetingCompleted => '已完成';

  @override
  String get meetingEmpty => '暂无会议记录';

  @override
  String get meetingEmptyHint => '点击上方按钮开始新的会议录制';

  @override
  String get meetingStarting => '正在启动会议...';

  @override
  String get meetingTitleHint => '输入会议标题...';

  @override
  String get meetingPause => '暂停';

  @override
  String get meetingResume => '继续';

  @override
  String get meetingStop => '结束';

  @override
  String get meetingListening => '正在录音...';

  @override
  String get meetingListeningHint => '语音会自动分段处理并转为文字';

  @override
  String get meetingTranscribing => '语音转文字中';

  @override
  String get meetingEnhancing => '文字整理中';

  @override
  String get meetingWaitingProcess => '等待处理';

  @override
  String get meetingPending => '等待';

  @override
  String get meetingDone => '完成';

  @override
  String get meetingError => '失败';

  @override
  String get meetingSegmentError => '处理失败';

  @override
  String get meetingRetry => '重试';

  @override
  String get meetingNoContent => '无转写内容';

  @override
  String get meetingProcessing => '正在处理剩余分段...';

  @override
  String get meetingSegments => '分段数';

  @override
  String get meetingLongPressToEnd => '长按按钮结束会议';

  @override
  String get meetingEndingConfirm => '正在结束会议...';

  @override
  String get meetingRecordingSegment => '正在录音...';

  @override
  String get meetingFullTranscription => '会议纪要';

  @override
  String get meetingStopConfirmTitle => '结束会议';

  @override
  String get meetingStopConfirm => '确定要结束当前会议录制吗？系统会先处理完所有已录制的分段。';

  @override
  String get meetingCancelConfirmTitle => '取消会议';

  @override
  String get meetingCancelConfirm => '确定要取消并丢弃当前会议吗？此操作不可撤销。';

  @override
  String get meetingDeleteConfirmTitle => '删除会议';

  @override
  String get meetingDeleteConfirm => '确定要删除这条会议记录吗？此操作不可撤销。';

  @override
  String get meetingDate => '日期';

  @override
  String get meetingDuration => '时长';

  @override
  String get meetingTotalChars => '总字数';

  @override
  String get meetingTitle => '会议标题';

  @override
  String get meetingSaved => '已保存';

  @override
  String get meetingSummary => '会议摘要';

  @override
  String get meetingContent => '会议内容';

  @override
  String get meetingCopyAll => '复制全文';

  @override
  String get meetingExportText => '导出为文本';

  @override
  String get meetingExportMarkdown => '导出为 Markdown';

  @override
  String get meetingExported => '已导出到剪贴板';

  @override
  String get meetingEmptyContent => '内容为空';

  @override
  String get meetingNotFound => '会议记录不存在';

  @override
  String get meetingOverlayStarting => '会议启动中';

  @override
  String get meetingOverlayRecording => '会议录音中';

  @override
  String get meetingOverlayPaused => '会议暂停';

  @override
  String get meetingOverlayProcessing => '会议处理中';

  @override
  String get meetingRecordingBanner => '会议录音进行中';

  @override
  String get meetingReturnToRecording => '返回录音';

  @override
  String get meetingSegmentView => '分段视图';

  @override
  String get meetingMergedNoteView => '合并纪要';

  @override
  String get meetingStreamingMerge => '合并中...';

  @override
  String get meetingDetailTab => '会议详情';

  @override
  String get meetingSummaryTab => '会议总结';

  @override
  String get meetingGeneratingSummary => '正在生成会议总结...';

  @override
  String get meetingNoSummary => '暂无会议总结';

  @override
  String get meetingRegenerateSummary => '重新生成';

  @override
  String get addToDictionary => '加入提示词词典';

  @override
  String get addedToDictionary => '已加入词典';

  @override
  String get home => '首页';

  @override
  String get settings => '设置';

  @override
  String get vendorLocalModel => '本地模型';

  @override
  String get vendorCustom => '自定义';

  @override
  String get localModelSttHint => '本地模型通过 FFI 直接调用 whisper.cpp，只需下载模型文件即可使用';

  @override
  String get localModelAiHint =>
      '本地模型通过 FFI 直接调用 llama.cpp，无需联网即可使用，支持 macOS 和 Windows';

  @override
  String get customTemplateSummary => '自定义模板';

  @override
  String get openModelDir => '打开模型文件所在目录';
}
