# voicetype

这是一个语音转文字输入的应用，配置了语音转换模型后可以轻松将语音输入转化成文字

## 启动调试

```
flutter run  -d macos
```

## 构建安装文件

```
flutter build macos
```
## 配置语音模型

推荐使用GLM的语音模型

|属性名|属性值|
|-----|-----|
|端点URL|https://open.bigmodel.cn/api/paas/v4|
|模型名称|GLM-ASR-2512|

## 配置文本模型（可选）

可以使用任意兼容OpenAI接口的服务

|属性名|属性值|
|-----|-----|
|端点URL|https://open.bigmodel.cn/api/paas/v4|
|模型名称|GLM-4.7|
