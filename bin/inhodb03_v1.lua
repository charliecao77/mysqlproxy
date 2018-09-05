
local tokenizer = require("proxy.tokenizer")
local DEBUG = os.getenv('DEBUG') or 0
DEBUG = DEBUG + 0
local l_Stoplog=""

local l_database=""
local l_unit=1

function connect_server()
  print("DB Server Using: " .. proxy.global.backends[1].dst.name)
end

function read_query(packet1)
  print("packet1:"..packet1:sub(1))
  if packet1:byte() ~= proxy.COM_QUERY then return end
	
  if packet1:byte() == proxy.COM_QUERY	then
    if string.match(packet1:upper(),'STANDARD_IMS_PROFILE') or 
       string.match(packet1:upper(),'STANDARD_OMS_PROFILE') or 
       string.match(packet1:upper(),'USER') or 
       string.match(packet1:upper(),'SYSTEM_PROPERTY')
    then
       proxy.response.type = proxy.MYSQLD_PACKET_ERR
       proxy.response.errmsg = "TABLE NOT ALLOW TO REVIEW!"
       print("No Permission");
       return proxy.PROXY_SEND_RESULT
    end	
		
    if 	proxy.connection.client.default_db =='information_schema' or
	proxy.connection.client.default_db =='mysql' 
    then
	proxy.response.type = proxy.MYSQLD_PACKET_ERR
	proxy.response.errmsg = "Use a Database except information_schema and mysql to apply for your states"
	print("Waiting for point to a database , Except database information_schema and mysql");
	return proxy.PROXY_SEND_RESULT
    end	
    print('[Current DB]:'..l_database..'[Chang to DB]:'..proxy.connection.client.default_db)
    if l_database ~= proxy.connection.client.default_db 
    then
       l_unit=1
       l_database = proxy.connection.client.default_db
    end
    local connect_info ="[MYSQL VERSION]:"..proxy.connection.server.mysqld_version..
			";[SERVER]:"..proxy.connection.server.dst.address..
			";[THREAD_ID]:"..proxy.connection.server.thread_id..
			";[PROXY]:"..proxy.connection.client.dst.address..
			";[Client addr]:"..proxy.connection.client.src.address..
			";[default_db]:"..proxy.connection.client.default_db..
			";[client]:"..proxy.connection.client.username
    local login_username=proxy.connection.client.username
    local release_name='Release '..os.date('%Y-%m-%d %H:%M:%S')
    local start_datetime=os.date('%Y-%m-%d %H:%M:%S')
    local begintime="select @begintime:=CURRENT_TIMESTAMP() as begintime ;"
    proxy.queries:append(2,string.char(proxy.COM_QUERY)..begintime,{resultset_is_needed = true})
    local query1 = packet1:sub(2)
    local query11 = query1:gsub('\\"','\\\\')
                    query11 = query11:gsub('"','\\"')
    proxy.queries:append(3,packet1,{resultset_is_needed = true})
    print("query1:"..query1)
    print("query11:"..query11)
    local tokens = tokenizer.tokenize(query1)
      for i = 1, 1 do 
        local token = tokens[i]
        if token["token_name"] == 'TK_SQL_CREATE'
	  or token["token_name"] == 'TK_SQL_DROP'
	  or token["token_name"] == 'TK_SQL_ALTER'
	  or token["token_name"] == 'TK_SQL_USE'
	  or token["token_name"] == 'TK_SQL_INSERT'
	  or token["token_name"] == 'TK_SQL_UPDATE'
	  or token["token_name"] == 'TK_SQL_DELETE'
	  or token["token_name"] == 'TK_SQL_SET'
	  or token["token_name"] == 'TK_LITERAL'
	  or token["token_name"] == 'TK_SQL_REPLACE'
	  or token["token_name"] == 'TK_SQL_REVOKE'
	  or token["token_name"] == 'TK_SQL_CALL'
	  or token["token_name"] == 'TK_SQL_LOCK'
	  or token["token_name"] == 'TK_SQL_UNLOCK'
	  or token["token_name"] == 'TK_SQL_RENAME'
	then
	  l_Stoplog = "NO"
	elseif token["token_name"] == 'TK_LITERAL' 
               and (token["text"]:upper() ~='ROLLBACK' 
               and token["text"]:upper() ~='COMMIT' 
               and token["text"]:upper() ~='FLUSH' 
               and token["text"]:upper() ~='TRUNCATE')   
        then	
	  l_Stoplog = "YES"
	  proxy.response.type = proxy.MYSQLD_PACKET_ERR
	  proxy.response.errmsg = "Error DDL/DML states ["..query1.."]"
	  print("Error: The operation ["..query1.."] not support! Note:".." { " .. token["token_name"] .. ", " .. token["text"]);
	  return proxy.PROXY_SEND_RESULT
	end
	print(i .. ": " .. " { " .. token["token_name"] .. ", " .. token["text"] .. " }" )
      end		
      return proxy.PROXY_SEND_QUERY
  end
end

function read_query_result(inj)
  if inj.id == 2 
  then
    return proxy.PROXY_IGNORE_RESULT
  elseif inj.id == 3 
  then
    local res = assert(inj.resultset,'Request sql is empty!')
    if res.query_status == proxy.MYSQLD_PACKET_ERR 
    then
      local out_string =
             'Time Stamp = ' .. os.date('%Y-%m-%d %H:%M:%S') .. 'n' ..
	     'Query      = ' .. inj.query:sub(2) .. 'n' ..
	     'Error Code = ' .. res.raw:byte(2)+(res.raw:byte(3)*256) .. 'n' ..
	     'SQL State  = ' .. string.format('%s', res.raw:sub(5, 9)) .. 'n' ..
	     'Err Msg    = ' .. string.format('%s', res.raw:sub(10)) .. 'n' ..
	     'Default DB = ' .. proxy.connection.client.default_db .. 'n' ..
	     'Username   = ' .. proxy.connection.client.username .. 'n' ..
	     'Address    = ' .. proxy.connection.client.src.name .. 'n' ..
	     'Thread ID  = ' .. proxy.connection.server.thread_id .. 'n'
      print("Error POP:"..out_string .. 'n')
      if l_Stoplog== 'NO' 
      then
        local inj_query = inj.query:sub(2):gsub('\\"','"')
        inj_query = inj_query:gsub('"','\\"')    
	proxy.queries:append(8,string.char(proxy.COM_QUERY) .. InsDeplErrorCentro,{resultset_is_needed = true})
      end
    end
  elseif inj.id == 4 
  then
    local res3 = assert(inj.resultset,"res3 is empty")
    if res3.query_status == proxy.MYSQLD_PACKET_ERR 
    then
      local out_string3 =
             'Time Stamp = ' .. os.date('%Y-%m-%d %H:%M:%S') .. 'n' ..
	     'Query      = ' .. inj.query:sub(2) .. 'n' ..
	     'Error Code = ' .. res3.raw:byte(2)+(res3.raw:byte(3)*256) .. 'n' ..
	     'SQL State  = ' .. string.format('%s', res3.raw:sub(5, 9)) .. 'n' ..
	     'Err Msg    = ' .. string.format('%s', res3.raw:sub(10)) .. 'n' ..
	     'Default DB = ' .. proxy.connection.client.default_db .. 'n' ..
	     'Username   = ' .. proxy.connection.client.username .. 'n' ..
	     'Address    = ' .. proxy.connection.client.src.name .. 'n' ..
	     'Thread ID  = ' .. proxy.connection.server.thread_id .. 'n'
      print(out_string3 .. 'n')
      proxy.response.type = proxy.MYSQLD_PACKET_ERR
      proxy.response.errmsg = "Insert into deployment_history table failure!"
      -- string.format('%s', res3.raw:sub(10))
      print("[Insert Deployment_history Table error]:"..string.format('%s', res3.raw:sub(10)));
      return proxy.PROXY_SEND_RESULT
    else 
      l_unit = l_unit +1
    end	
    return proxy.PROXY_IGNORE_RESULT
  elseif inj.id == 41 
  then
    return proxy.PROXY_IGNORE_RESULT
  elseif inj.id == 5 
  then
    local res31 = assert(inj.resultset,"res31 is empty")
    if res31.query_status == proxy.MYSQLD_PACKET_ERR 
    then
      local out_string31 =
             'Time Stamp = ' .. os.date('%Y-%m-%d %H:%M:%S') .. 'n' ..
	     'Query      = ' .. inj.query:sub(2) .. 'n' ..
	     'Error Code = ' .. res3.raw:byte(2)+(res3.raw:byte(3)*256) .. 'n' ..
	     'SQL State  = ' .. string.format('%s', res3.raw:sub(5, 9)) .. 'n' ..
	     'Err Msg    = ' .. string.format('%s', res3.raw:sub(10)) .. 'n' ..
	     'Default DB = ' .. proxy.connection.client.default_db .. 'n' ..
	     'Username   = ' .. proxy.connection.client.username .. 'n' ..
	     'Address    = ' .. proxy.connection.client.src.name .. 'n' ..
	     'Thread ID  = ' .. proxy.connection.server.thread_id .. 'n'
      -- print(out_string31 .. 'n')
      proxy.response.type = proxy.MYSQLD_PACKET_ERR
      proxy.response.errmsg = "Insert into deploymentdb.deployment_history_all table failure!"
      -- string.format('%s', res31.raw:sub(10))
      print("[Insert Deploymentdb.Deployment_history Table error]:"..string.format('%s', res31.raw:sub(10)));
      return proxy.PROXY_SEND_RESULT
    end	
    return proxy.PROXY_IGNORE_RESULT
  elseif inj.id == 6 
  then
    local res5 = assert(inj.resultset,"res5 is empty")
    if res5.query_status == proxy.MYSQLD_PACKET_ERR 
    then
      error_result(string.format('%s', res5.raw:sub(10)),
                   res5.raw:byte(2)+(res5.raw:byte(3)*256),
		   inj.query:sub(2))
      return proxy.PROXY_SEND_RESULT				
    end
      return proxy.PROXY_IGNORE_RESULT
  elseif inj.id == 7 
  then
    local res6 = assert(inj.resultset,"res6 is empty")
    if res6.query_status == proxy.MYSQLD_PACKET_ERR 
    then
      error_result(string.format('%s', res6.raw:sub(10)),
                   res6.raw:byte(2)+(res6.raw:byte(3)*256),
		   inj.query:sub(2))
      return proxy.PROXY_SEND_RESULT				
    end
    return proxy.PROXY_IGNORE_RESULT
  elseif inj.id == 8 then
    local res8 = assert(inj.resultset,"res8 is empty")
    if res8.query_status == proxy.MYSQLD_PACKET_ERR 
    then
      error_result(string.format('%s', res6.raw:sub(10)),
                   res8.raw:byte(2)+(res8.raw:byte(3)*256),
		   inj.query:sub(2))
      return proxy.PROXY_SEND_RESULT				
    end
    return proxy.PROXY_IGNORE_RESULT
  end
end

function print_debug(msg,level)
	level = level or 1
	if debug >= level then
		print (msg)
	end
end

function error_result(msg,code,state)
	proxy.response = {
		type = proxy.MYSQLD_PACKET_ERR,
		errmsg = msg,
		errcode = code,
		sqlstate = state,
	}
	print("recording process error:"..proxy.response.errmsg);
	-- return proxy.PROXY_SEND_RESULT
	
end
