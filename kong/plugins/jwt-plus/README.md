# kong-jwt-plus
##说明
实现了Jwt拦截，登录时调用第三方登录接口。登录后会生成JWT-token，把返回的jwt-token放入hearder里面，下次请求插件会解析出加密前的登录信息，放入hearder里面，然后再访问相应的业务系统

## 配置

#####修改redis.lua下的redis配置
 * **redis_host** - Redis 的 Hostname or IP
 * **redis_port** - Redis Port (默认为 6379)
 * **redis_password** - Redis 密码 (默认为空)

#####修改api.lua下的第三方登录接口配置
 * **ConsumerId** -在kong上面生成Consumer，命名为如下的：“psplocal”，跟登录地址配置时的名称一致，然后生成consumer对应的jwt token)
 * **ssobody** - 请求参数，根据具体项目做修改


## 使用

#####kong开启改插件（教程很多）


#####登录接口
* **地址**--kong:8001/sso/consumers/jwt/login
* **方法**--Post
* **参数**--请求参数，根据具体项目做修改(例子中是Phone,Captcha,ConsumerId）
* **返回**--Jwt-token

#####hearder
* **authorization**：Bearer + Jwt-token

#####退出登录（包含踢下线）
* **地址**--kong:8001/sso/consumers/jwt/forbid_login
* **方法**--Post
* **参数**--uid，根据具体项目做修改(例子中是第三方登录返回的UserInfo中的UserId）


