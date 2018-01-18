local crud = require "kong.api.crud_helpers"
local singletons = require "kong.singletons"
local http = require "resty.http"
local cjson = require "cjson"
local jwt_encoder = require "kong.plugins.jwt-plus.jwt_parser"
local ngx_time = ngx.time
local utils = require "kong.tools.utils"
local redis = require "kong.plugins.jwt-plus.redis"
local responses = require "kong.tools.responses"
-- 设置token有效期,当前是第四天零点
JWT_EXP_TIME = 345600

SSO_API_MAP = {
   -- 登录接口的地址配置，当前的请求参数为ConsumerId(这个在kong上面生成Consumer，命名为如下的：“psplocal”)
    psplocal = {
      host = "http://localhost:15000/api/v1.0/login/admin",
      token = "Basic "
    },
    psptest = {
      host = "http://XXXX:15000/api/v1.0/login/admin",
      token = "Basic "
    },
}


local function ret(msg)

    return false,msg
end



local function load_secret(consumer_id)
  local rows, err = singletons.dao.jwt_secrets:find_all {consumer_id = consumer_id}
  if err then
    return nil, err
  end
  return rows[1]
end

local function sso_login(params) 
  -- 通过consumer_id获取username既环境名
 local consumer_rows ,err = singletons.dao.consumers:find_all {id = params.ConsumerId}
  if next(consumer_rows) == nil or err then
    return ret('ConsumerId not exist')
  end

  local project_name = consumer_rows[1].username

  SSO_API = SSO_API_MAP[project_name]

  local httpc = http.new()
  local ssobody = ''

  if string.find(project_name, "psp") ~= nil then
    ssobody = '{"Phone":"' .. params.Phone .. '","Captcha":"' .. params.Captcha .. '"}'
  end


  local res, err = httpc:request_uri(
      SSO_API.host,
      {
        ssl_verify = ssl_verify or false,
        headers = { Authorization = SSO_API.token,
                    ["Content-Type"] = "application/json;"},
        method = "POST",
        body = ssobody,
      }
  )
  if not res or err or 200 ~= res.status then
 
      return ret('登录失败，请检查登录信息')
  end

  local ret_info = cjson.decode(res.body)
  if ret_info.success == false then
      return ret(ret_info.msg)
  end




  local user_info = ret_info["resultData"]["user_info"]

   local data = {}

  
 

  local secret = load_secret(params.ConsumerId)

  if not secret then

      return ret('cant not find key.')
  end  

  local temp_date = os.date("*t", os.time())
  local expcount = os.time({year=temp_date.year, month=temp_date.month, day=temp_date.day, hour=0}) + JWT_EXP_TIME

  if string.find(project_name, "psp") ~= nil then
    data = {
      key = secret.key,
      uid = user_info.UserId,
      user_info = user_info,
      exp = expcount,
      token = user_info.UserId.."/"..secret.key.."/"..utils:random_string()
    }
  elseif string.find(project_name, "xiao") ~= nil then
    data = {
      key = secret.key,
      uid = user_info.uid,
      user_info = user_info,
      exp = expcount,
      token = user_info.uid.."/"..secret.key.."/"..utils:random_string()
    }
    end

  local new_token = jwt_encoder:encode_token(data, secret.secret)

  local resp,err = redis:save_newtoken(data.token)
  if err then
    return ret('can not save token')
  end
  
  return new_token
end


return {

-- 完成密码登录验证
-- 完成jwt返回
-- 修改header头，增加uid

  ["/sso/consumers/jwt/login"] = {
    before = function(self, dao_factory, helpers)
      
    end,

    GET = function(self, dao_factory)
      return helpers.responses.send_HTTP_OK(self.params)
    end,

    POST = function(self, dao_factory, helpers)
      -- local jwt_token ,err= sso_login(self.params)
      local jwt_token,err = sso_login(self.params)
      if err then
        return responses.send(200,{resultCode = 400,resultMessage = err,resultData=null})
      end
      return responses.send(200,{resultCode = 0,resultMessage = "0",resultData=jwt_token})    
    end

  },

  ["/sso/consumers/jwt/forbid_login"] = {
    before = function(self, dao_factory, helpers)
      
    end,

    GET = function(self, dao_factory)
      return helpers.responses.send_HTTP_OK(self.params)
    end,

    POST = function(self, dao_factory, helpers)
      local tokens,err = redis:get_tokens_uid(self.params.uid)
      if err then
        return helpers.responses.send_HTTP_NOT_FOUND(err)
      end

      local res,err = redis:del_token(tokens)
      if err then
        return responses.send(200,{resultCode = 400,resultMessage = err,resultData=null})
      end
      return responses.send(200,{resultCode = 0,resultMessage = "0",resultData=null}) 
    end

  }
  
}