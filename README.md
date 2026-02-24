# voicetype

这是一个语音转文字输入的应用，配置了语音转换模型后可以轻松将语音输入转化成文字，并且会在文字转化完成后，自动插入当前应用的光标所在的位置，实现自动输入。

## 启动调试

### mac电脑
```
flutter run  -d macos
```

### windows电脑
```
flutter run  -d windows
```

## 构建安装文件

如果要在自己电脑上构建，使用以下的方式，如果要直接下载使用，在这里[下载安装文件](https://github.com/tyro668/voicetype/releases)。

**注意：** mac上使用该应用需要自己去隐私与安全性中允许该应用

### mac版本
```
flutter build macos --release
```

### windows版本
```
flutter build windows --release
```

## 一键构建脚本

macOS (DMG):

```
./scripts/build-macos.sh
```

Windows (EXE):

```
powershell -ExecutionPolicy Bypass -File scripts/build-windows.ps1
```
## 配置语音模型

推荐使用GLM的语音模型，直接访问[智普的官网](https://bigmodel.cn/usercenter)充值10块钱，然后新建好API Key后，在应用中进行配置即可。

|属性名|属性值|
|-----|-----|
|端点URL|https://open.bigmodel.cn/api/paas/v4|
|模型名称|GLM-ASR-2512|

也可以使用阿里云 DashScope 的语音模型 (兼容 OpenAI 接口模式)

|属性名|属性值|
|-----|-----|
|端点URL|https://dashscope.aliyuncs.com/compatible-mode/v1|
|模型名称|qwen3-asr-flash|

## 配置文本模型（可选）

可以使用任意兼容OpenAI接口的服务

|属性名|属性值|
|-----|-----|
|端点URL|https://open.bigmodel.cn/api/paas/v4|
|模型名称|GLM-4.7|

## 用户界面

通用设置
![通用设置](screenshots/main.png)
语音模型设置
![语音模型设置](screenshots/voice_setting.png)

录音效果
![录音效果](screenshots/record.png)

