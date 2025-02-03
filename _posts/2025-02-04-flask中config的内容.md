---
layout: post
title:  "flask中config的内容"
date:   2012-02-04 03:00:00 +0800
categories: B站弹幕姬
---
# **config包含什么**

## 1. SECRET_KEY
```python
app.config['SECRET_KEY'] = 'your-secret-key'
```
Flask 默认并不启用 `session`,我们需要通过`SECRET_KEY`来启用它。如果没有设置,Flask 会抛出异常。

在 Flask 中，`session` 是一种机制，用于在不同的请求之间存储和保持用户数据。它通常用于实现用户身份验证、保存用户偏好设置、跟踪用户活动等功能。`session` 是一个字典对象，它允许你将数据存储在浏览器的 cookies 中，以便在用户发出多个请求时保持状态。

这个键的作用类似于你家的主钥匙。它用于：

- 加密会话数据
- 保护表单（CSRF保护）
- Flask-Login等扩展的安全功能

如果缺失SECRET_KEY：

- 用户会话将无法正常工作
- 表单提交会失败
- 任何依赖加密的功能都会报错

## 2. DEBUG
```python
app.config['DEBUG'] = False
```
这是Flask最基础的调试开关。当设置为True时：

- 应用会在代码变更时自动重载
- 错误页面会显示详细的回溯信息
- Werkzeug调试器会被激活

在生产环境中必须设置为False，否则会暴露敏感信息。

## 3. TESTING
```python
app.config['TESTING'] = False
```
测试模式开关，设置为True时：

- 错误会被传播而不是被处理
- 密码学相关的令牌生成会使用可预测的值
- Flask-Mail不会真正发送邮件

## 4. PRESERVE_CONTEXT_ON_EXCEPTION
## **此条不用阅读，一整条都不用，实在想看可以看，正常情况下你完全不会去调用PRESERVE_CONTEXT_ON_EXCEPTION**
这是Flask中一个较为复杂但非常重要的配置，它与Flask的上下文管理系统密切相关。
首先，我们需要理解Flask中的"上下文"概念。想象Flask应用就像一个舞台剧，每个请求都是一个场景，而上下文就是这个场景中的布景和道具。在正常情况下，当一个场景（请求）结束时，工作人员（Flask）会清理舞台（上下文）。但如果演出过程中出现意外（异常），我们是应该立即清理舞台还是保持现状以便查看问题？这就是 `PRESERVE_CONTEXT_ON_EXCEPTION` 要解决的问题。

```python
app.config['PRESERVE_CONTEXT_ON_EXCEPTION'] = None  # 默认值
```

这个配置的行为较为特殊：

1. 当值为 None 时（默认值）：

- 在调试模式下（DEBUG=True）：自动设置为 True
- 在生产模式下：自动设置为 False


2. 当值为 True 时：

```python
try:
    # 某个可能抛出异常的操作
    db.session.add(user)
    db.session.commit()
except Exception as e:
    # 此时仍然可以访问请求上下文
    current_app.logger.error(f"Error occurred for user {request.form['username']}")
    raise
```
在这种情况下，即使发生异常，你仍然可以访问：

- request 对象（当前请求的信息）
- session 对象（用户会话数据）
- g 对象（请求级别的全局变量）
- current_app 对象（当前应用实例）


当值为 False 时：
```python
try:
    db.session.add(user)
    db.session.commit()
except Exception as e:
    # 此时请求上下文已经被清理
    # 下面的代码会引发 RuntimeError: Working outside of request context
    current_app.logger.error(f"Error occurred for user {request.form['username']}")
    raise
```
### 实际应用

1. 调试环境
```python
app.config.update(
    DEBUG=True,
    PRESERVE_CONTEXT_ON_EXCEPTION=True
)
```
这样配置可以：

- 在异常发生时检查请求数据
- 在调试器中访问完整的上下文信息
- 更容易理解错误发生的原因


2. 生产环境
```python
app.config.update(
    DEBUG=False,
    PRESERVE_CONTEXT_ON_EXCEPTION=False
)
```
这样配置可以：

- 确保资源及时释放
- 避免内存泄漏
- 提高应用的稳定性


3. 自定义错误处理
```python
@app.errorhandler(Exception)
def handle_error(error):
    if app.config['PRESERVE_CONTEXT_ON_EXCEPTION']:
        # 可以安全地访问请求上下文
        user_agent = request.headers.get('User-Agent')
        log_error(error, user_agent)
    return "An error occurred", 500
```

一般不推荐你使用这个东西，如果你实在想用……

```python
class Config:
    # 基础配置
    PRESERVE_CONTEXT_ON_EXCEPTION = None  # 让Flask根据环境决定

class DevelopmentConfig(Config):
    DEBUG = True
    # 在开发环境中，PRESERVE_CONTEXT_ON_EXCEPTION 会自动变为 True

class ProductionConfig(Config):
    DEBUG = False
    # 在生产环境中，PRESERVE_CONTEXT_ON_EXCEPTION 会自动变为 False
    
    def handle_exception(e):
        # 在这里进行生产环境的错误处理
        pass
```

## 5. SESSION_COOKIE_HTTPONLY
```python
app.config['SESSION_COOKIE_HTTPONLY'] = True
```

安全增强配置：

- 防止JavaScript访问会话cookie
- 减少XSS攻击的风险
- 建议始终保持开启。

## 6. SESSION_COOKIE_SECURE
```python
app.config['SESSION_COOKIE_SECURE'] = False
```
控制cookie的安全传输：

- True时只通过HTTPS发送cookie
- 在生产环境的HTTPS站点应该设为True

## 7. PERMANENT_SESSION_LIFETIME
```python
app.config['PERMANENT_SESSION_LIFETIME'] = 31  # days
```
控制永久会话的有效期：

- 可以设置为整数（天数）或timedelta对象
- 影响"记住我"功能的持续时间

## 8. SESSION_REFRESH_EACH_REQUEST
```python
app.config['SESSION_REFRESH_EACH_REQUEST'] = True
```
会话刷新策略：

- True时每个请求都会刷新会话的过期时间
- 有助于保持活跃用户的登录状态

## 9. SESSION_COOKIE_DOMAIN
```python
app.config['SESSION_COOKIE_DOMAIN'] = None
```
会话cookie的域名设置：

- 控制cookie在哪些子域名下可用
- None表示仅在当前域名有效

## 10. SERVER_NAME
```python
app.config['SERVER_NAME'] = None
```
应用的域名配置：

- 用于URL生成
- 影响子域名路由

如果设置不当可能导致URL生成错误。

## 11. PREFERRED_URL_SCHEME
```python
app.config['PREFERRED_URL_SCHEME'] = 'http'
```
URL生成时的默认协议：

- 影响url_for()生成的URL
- 生产环境应该设置为'https'

## 12. MAX_CONTENT_LENGTH
```python
app.config['MAX_CONTENT_LENGTH'] = None
```
请求大小限制：

- 设置上传文件的最大大小
- None表示无限制（不推荐）

如果设置为字节数， Flask 会拒绝内容长度大于此值的请求进入，并返回一个 413 状态码

## 13. JSON_AS_ASCII
```python
app.config['JSON_AS_ASCII'] = True
```
JSON序列化的字符编码：

- True时强制使用ASCII
- False允许Unicode字符

处理非英文内容时应设为False。

## 14. JSON_SORT_KEYS
```python
app.config['JSON_SORT_KEYS'] = True
```
JSON响应的键排序：

- True时确保响应一致性,不会受到字典的哈希种子的影响
- 有助于HTTP缓存优化

## 15. TEMPLATES_AUTO_RELOAD
```python
app.config['TEMPLATES_AUTO_RELOAD'] = None
```
模板自动重载：

- 开发时设为True方便调试
- 生产环境应为False以提高性能

## 16. TRAP_BAD_REQUEST_ERRORS
```python
app.config['TRAP_BAD_REQUEST_ERRORS'] = False
```
错误处理定制：

- True时允许调试HTTP 400错误
- 有助于诊断请求处理问题

调试时找出 HTTP 异常源头有用

## 17. TRAP_HTTP_EXCEPTIONS
```python
app.config['TRAP_HTTP_EXCEPTIONS'] = False
```
HTTP异常处理：

- True时禁用HTTP异常处理
- 用于调试特定的HTTP错误

## 18. USE_X_SENDFILE
```python
app.config['USE_X_SENDFILE'] = False
```
这是一个与文件服务相关的高级配置。

图书馆管理员（Flask）可以选择自己搬运书籍（False）或指示助手（Web服务器）去搬运（True）。
当设置为True时：

- Flask会让Web服务器（如Apache或Nginx）处理静态文件的发送
- 服务器使用X-Sendfile头部进行文件传输

可以显著提高大文件传输的性能

### 示例
```python
# Nginx配置示例
location /protected/ {
    internal;
    alias /path/to/protected/files/;
}

# Flask应用
app.config['USE_X_SENDFILE'] = True

@app.route('/download/<path:filename>')
def download(filename):
    return send_file(f"/protected/{filename}", as_attachment=True)
```

## 19. SEND_FILE_MAX_AGE_DEFAULT
```python
app.config['SEND_FILE_MAX_AGE_DEFAULT'] = 12  # hours
```
这控制静态文件的缓存时间：

- 影响静态文件的Cache-Control头部
- 默认为12小时
- 可以通过send_file()函数的参数覆盖

## 20. LOGGER_NAME
```python
app.config['LOGGER_NAME'] = None
```
这就像给你的日记本取一个名字，用于：

- 标识应用的日志记录器
- 区分多个应用的日志
- 配置特定的日志处理策略

## 21. LOGGER_HANDLER_POLICY

```python
app.config['LOGGER_HANDLER_POLICY'] = 'always'
```
控制日志处理器的行为，可选值：

- 'always'：始终添加处理器
- 'never'：从不添加处理器
- 'production'：仅在生产环境添加处理器

## **本条之后的内容可以完全不需要阅读**

### 示例

```python
import logging
from flask import Flask

def setup_logger(app):
    """设置应用的日志系统"""
    if not app.config['LOGGER_NAME']:
        return

    logger = logging.getLogger(app.config['LOGGER_NAME'])
    logger.setLevel(logging.INFO)

    # 根据 LOGGER_HANDLER_POLICY 决定是否添加处理器
    policy = app.config['LOGGER_HANDLER_POLICY']
    
    if policy == 'always':
        # 始终添加处理器
        handler = logging.FileHandler('application.log')
        formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        handler.setFormatter(formatter)
        logger.addHandler(handler)
    
    elif policy == 'production':
        # 只在生产环境添加处理器
        if not app.debug:  # 检查是否为生产环境
            handler = logging.FileHandler('production.log')
            formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
            handler.setFormatter(formatter)
            logger.addHandler(handler)
    
    elif policy == 'never':
        # 不添加处理器，可能使用其他配置方式
        pass

    # 创建应用示例
app = Flask(__name__)
app.config.update(
    LOGGER_NAME='my_application',
    LOGGER_HANDLER_POLICY='production'
)

    # 设置日志系统
setup_logger(app)

@app.route('/')
def index():
    logger = logging.getLogger(app.config['LOGGER_NAME'])
    logger.info('访问了首页')
    return 'Hello World!'
```

### 实际应用

```python
# 开发环境配置
app.config.update(
    LOGGER_NAME='development',
    LOGGER_HANDLER_POLICY='never'  # 在开发时使用控制台输出
)

# 生产环境配置
app.config.update(
    LOGGER_NAME='production',
    LOGGER_HANDLER_POLICY='always'  # 在生产环境始终记录日志
)
```
### 层次性
```python
def create_app():
    app = Flask(__name__)
    
    # 基础日志配置
    app.config['LOGGER_NAME'] = 'myapp'
    
    if app.env == 'development':
        app.config['LOGGER_HANDLER_POLICY'] = 'never'
        # 开发环境使用控制台输出
        logging.basicConfig(level=logging.DEBUG)
    else:
        app.config['LOGGER_HANDLER_POLICY'] = 'always'
        # 生产环境使用文件日志
        setup_logger(app)
        
    return app
```
## 22. APPLICATION_ROOT

```python
app.config['APPLICATION_ROOT'] = None
```
设置应用的根路径：

- 用于子应用程序挂载
- 影响URL生成
- 对反向代理配置很重要

## 23. SESSION_COOKIE_PATH
```python
app.config['SESSION_COOKIE_PATH'] = None
```
控制会话cookie的可用路径：

- None表示使用APPLICATION_ROOT
- 可以限制cookie只在特定路径下可用
- 有助于提高安全性

## 24. SESSION_COOKIE_NAME
```python
app.config['SESSION_COOKIE_NAME'] = 'session'
```
定义存储会话数据的cookie名称：

- 默认为'session'
- 在多应用环境中应该使用不同的名称
- 影响客户端存储的cookie标识

## 25. EXPLAIN_TEMPLATE_LOADING
```python
app.config['EXPLAIN_TEMPLATE_LOADING'] = False
```
这是一个调试工具：

- True时会显示模板加载的详细过程
- 帮助理解模板继承和覆盖
- 对调试模板问题很有用

## 26. JSONIFY_PRETTYPRINT_REGULAR
```python
app.config['JSONIFY_PRETTYPRINT_REGULAR'] = True
```
控制JSON响应的格式化：

- True时生成缩进的、易读的JSON
- 在开发环境中便于调试
- 可能增加响应大小

## 27. JSONIFY_MIMETYPE
```python
app.config['JSONIFY_MIMETYPE'] = 'application/json'
```
设置JSON响应的MIME类型：

- 影响Content-Type头部
- 可以自定义为其他JSON相关的MIME类型
- 影响客户端如何处理响应

### 示例
```python
class Config:
    # 生产环境配置
    USE_X_SENDFILE = True
    SEND_FILE_MAX_AGE_DEFAULT = 24 * 60 * 60  # 1 day
    LOGGER_NAME = 'production_app'
    APPLICATION_ROOT = '/myapp'
    SESSION_COOKIE_PATH = '/myapp'
    JSONIFY_PRETTYPRINT_REGULAR = False  # 生产环境禁用美化

class DevelopmentConfig(Config):
    # 开发环境配置
    USE_X_SENDFILE = False
    SEND_FILE_MAX_AGE_DEFAULT = 0  # 禁用缓存
    EXPLAIN_TEMPLATE_LOADING = True
    JSONIFY_PRETTYPRINT_REGULAR = True

@app.route('/api/data')
def get_data():
    data = {'name': 'example', 'value': 42}
    return jsonify(data)  # 将使用配置的JSONIFY_MIMETYPE
```