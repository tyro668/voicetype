# voicetype

这是一个语音转文字输入的应用，配置了语音转换模型后可以轻松将语音输入转化成文字，并且会在文字转化完成后，自动插入当前应用的光标所在的位置，实习自动输入。

## 启动调试

```
flutter run  -d macos
```

## 构建安装文件

```
flutter build macos
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

推荐使用GLM的语音模型

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

