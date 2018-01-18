local redis = require "resty.redis"
local ngx_log = ngx.log
local cjson_decode = require("cjson").decode
local cjson_encode = require("cjson").encode
local redis_host = "localhost"
local redis_port = 6379
local redis_password = ""
local _M = {}
_M.__index = _M



function _M.save_newtoken(self,token)
  local red = connectme()
  local ok, err = red:set(token,'0')
  if err then
    ngx_log(ngx.ERR, "[redis-log] can't save to Redis: ", err)
    return false, err
  end
  return true
end

function _M.exist_token(self,token)
  local red = connectme()
  local resp, err = red:keys(token)
  if err then
    return false, err
  end
  if  next(resp) == nil then
    return false ,{status = 401, message = "登录信息失效"}
  end
  return resp
end


function _M.del_token(self,tokens)
  local red = connectme()
  red:init_pipeline()
  for i in pairs(tokens) do
    red:del(tokens[i])
  end
  local ok, err = red:commit_pipeline()
  if not ok then
    return false, err
  end
end

function _M.get_tokens_uid(self,uid)
  local red = connectme()
  local tokens, err = red:keys(uid.."*") 
  if next(tokens) == nil then
    return false,  "token不存在"
  end
  return tokens
end

function connectme()
  local red = redis:new()
  red:set_timeout(1000)

  local ok, err = red:connect(redis_password, redis_port)

  if not ok then
    ngx_log(ngx.ERR, "[redis-log] failed to connect to Redis: ", err)
    return
  end

  local ok, err = red:auth(redis_password)
  if not ok then
    ngx_log(ngx.ERR, "failed to connect to Redis: ", err)
    return
  end


  return red
end

return _M