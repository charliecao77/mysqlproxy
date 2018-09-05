
local tokenizer = require("proxy.tokenizer")
local DEBUG = os.getenv('DEBUG') or 0
DEBUG = DEBUG + 0
local l_Stoplog=""

local l_database=""
local l_unit=1

function connect_server()
        print("Deploy on DB Server Using: " .. proxy.global.backends[1].dst.name)
end

function read_query(packet1)
	-- print("packet1:"..packet1:sub(1))
	if packet1:byte() ~= proxy.COM_QUERY then return end
	
	if packet1:byte() == proxy.COM_QUERY	then
		-- no create or remove database operation. string.match(packet1:upper(),'"') or
		if string.match(packet1:upper(),'DROP DATABASE') or 
		string.match(packet1:upper(),'DROP DATABASE IF EXISTS')
		-- if string.match(packet1:upper(),'DROP DATABASE') or 
		--	string.match(packet1:upper(),'DROP DATABASE IF EXISTS') or 
		--	string.match(packet1:upper(),'CREATE DATABASE') 
			
			
		then
			proxy.response.type = proxy.MYSQLD_PACKET_ERR
			
			proxy.response.errmsg = "Drop/Create database is not allowed"
		--	if string.match(packet1:upper(),'"') then
		--		proxy.response.errmsg = "Please change the character [\"] to [']"
		--		print("we don't allow the character [\"]");
		--	elseif string.match(packet1:upper(),"''") then
		--		proxy.response.errmsg = "Please change the double character [\''] to single [']"
		--		print("we don't allow the double character [\'']");
		--	elseif string.match(packet1:upper(),"\\\\") then
		--		proxy.response.errmsg = "Please change the double character [\\\\] to single [\\]"
		--		print("we don't allow the double character [\\\\]");
		--	else
				print("we don't allow client to do the drop/create database operation");
			
		--	end 
			return proxy.PROXY_SEND_RESULT
			
		end	
		
		if  proxy.connection.client.default_db =='' or  
			proxy.connection.client.default_db =='information_schema' or
			proxy.connection.client.default_db =='mysql' 
		then
			proxy.response.type = proxy.MYSQLD_PACKET_ERR
			proxy.response.errmsg = "Use a Database except information_schema and mysql to apply for your states"
			print("Waiting for use a database before running states, except database information_schema and mysql");
			return proxy.PROXY_SEND_RESULT
		end	
		
		-- difference database the unit need recount.
		if l_database=='' then
			l_database = proxy.connection.client.default_db
		end	
		print('[Current DB]:'..l_database..'[Chang to DB]:'..proxy.connection.client.default_db)
		if l_database ~= proxy.connection.client.default_db then
			l_unit=1
			l_database = proxy.connection.client.default_db
			
		end
		
		-- prepare the value for the deployment_history log.
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
		
		local server_check= "select count(1) "..
							" 	from deploymentdb.deployment_environment "..
							" 	where db_server= @@hostname "..
							" 	AND db_port=@@port;"
	-- 	proxy.queries:append(1,string.char(proxy.COM_QUERY)..server_check,{resultset_is_needed = true})
		
		local begintime="select @begintime:=CURRENT_TIMESTAMP() as begintime ;"
		proxy.queries:append(2,string.char(proxy.COM_QUERY)..begintime,{resultset_is_needed = true})
		
		local query1 = packet1:sub(2)

		-- local query11 = query1:gsub('\\"','"')
                --    query11 = query11:gsub('"','\\"')
                --    query11 = query11:gsub('\\\\"','\\\\\\\\\\"')
		local query11 = query1:gsub('\\"','\\\\')
                    query11 = query11:gsub('"','\\"')
		proxy.queries:append(3,packet1,{resultset_is_needed = true})
		
		print("query1:"..query1)
		print("query11:"..query11)
		
		local InsertDeplHis = "insert into deployment_history(release_name,"..
					--	" oid_deployment_env, "..
						" db_server, "..
						" db_port, "..
						" db_id, "..
						" ticket_name, "..
						" script_name, "..
						" database_name, "..
						" developer_name, "..
						" description, "..
						" unit_number, "..
						" start_datetime, "..
						" finish_datetime, "..
						" sql_state) "..
						" select if(ifnull(@release_name,'')='','"..release_name.."',@release_name) as release_name"..
					--		" 	,(select oid_deployment_env "..
					--		" 	from deploymentdb.deployment_environment "..
					--		" 	where db_server= @@hostname "..
				--			" 	AND db_port=@@port "..
				--			" 	) as oid_deployment_env "..
							"	,@@hostname as db_server"..
							"	,@@port as db_port"..
							" 	,(select ifnull(max(db_id),0)+1 from deployment_history as dh)as db_id "..
							" 	,ifnull(@ticket_name,'') as ticket_name "..
							" 	,ifnull(@script_name,'') as script_name "..
							" 	,schema() as database_name "..
							" 	,if(ifnull(@developer_name,'')='','"..login_username.."',@developer_name) as developer_name "..
							" 	,if(ifnull(@description,'')='','"..connect_info.."',@description) as description "..
							" 	,"..l_unit.." as unit_number "..
							" 	,@begintime as start_datetime "..
							" 	,now() as finish_datetime "..
							' 	,"'.. query11 ..'" as sql_state '..
						" from dual; "
						-- str_to_date('"..start_datetime.."','%Y-%m-%d %H:%i:%s') as start_datetime
		 -- " 	,@unit_number:=ifnull(@unit_number,0) +1 as unit_number "..
		 local CurrentOidDeplHis = "select @i_oid_dh:=last_insert_id() ;"
		 
			local InsertDeplHisCentro = "insert into deploymentdb.deployment_history_all(oid_sub_deployment_history,"..
					" release_name, "..
					" db_server, "..
					" db_port, "..
					" db_id, "..
					" ticket_name, "..
					" script_name, "..
					" database_name, "..
					" developer_name, "..
					" description, "..
					" unit_number, "..
					" start_datetime, "..
					" finish_datetime, "..
					" sql_state) "..
					" select 	oid_deployment_history, "..
					" 			release_name, "..
					" 			db_server, "..
					" 			db_port, "..
					" 			db_id, "..
					" 			ticket_name, "..
					" 			script_name, "..
					" 			database_name, "..
					" 			developer_name, "..
					" 			description, "..
					" 			unit_number, "..
					" 			start_datetime, "..
					" 			finish_datetime, "..
					" 			sql_state "..
					" from deployment_history "..
					" where oid_deployment_history=@i_oid_dh;"
		 
		 

		 
		local tokens = tokenizer.tokenize(query1)
		-- for i = 1, #tokens do
		-- only look at the first one.
		for i = 1, 1 do 
            local token = tokens[i]
			-- 'TK_SQL_DELETE' 'TK_SQL_UPDATE' 'TK_SQL_INSERT'
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
				proxy.queries:append(4,string.char(proxy.COM_QUERY) .. InsertDeplHis,{resultset_is_needed = true})
				proxy.queries:append(41,string.char(proxy.COM_QUERY) .. CurrentOidDeplHis,{resultset_is_needed = true})
				proxy.queries:append(5,string.char(proxy.COM_QUERY) .. InsertDeplHisCentro,{resultset_is_needed = true})
			
			elseif token["token_name"] == 'TK_LITERAL' and (token["text"]:upper() ~='ROLLBACK' and token["text"]:upper() ~='COMMIT' and token["text"]:upper() ~='FLUSH' and token["text"]:upper() ~='TRUNCATE')   then	
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
		-- print_debug(packet1:sub(2),1)	
		-- print_debug('inside read_query',2)
end

function read_query_result(inj)
--	if inj.id == 1 then
--		for row in inj.resultset.rows do
			-- print("effect rows:"..row[1])
--			if row[1] == '0' then
--				proxy.response.type = proxy.MYSQLD_PACKET_ERR
--				proxy.response.errmsg = "current server need add into deploymentdb.deployment_environment table"
--				print("Error: current server need add into deploymentdb.deployment_environment table.");
--				return proxy.PROXY_SEND_RESULT
--			end
--		end
--	return proxy.PROXY_IGNORE_RESULT
--	else
	if inj.id == 2 then
	return proxy.PROXY_IGNORE_RESULT
	elseif inj.id == 3 then
		local res = assert(inj.resultset,'Request sql is empty!')
		if res.query_status == proxy.MYSQLD_PACKET_ERR then
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
			
			if l_Stoplog== 'NO'then
				local inj_query = inj.query:sub(2):gsub('\\"','"')
                                   inj_query = inj_query:gsub('"','\\"')    
				local InsDeplErrorCentro="	insert into deploymentdb.deployment_error_all(oid_sub_deployment_history,database_name,error_DDL,error_no,error_message,execute_timestamp) "..
									 "	select oid_deployment_history,schema(),error_DDL,error_no,error_message,execute_timestamp "..
									 "	from deployment_error "..
								     "  where oid_deployment_history=@i_oid_dh;"
				-- print("last insert_id:"..inj.resultset.insert_id)
				-- print('inj.response_time:'..inj.response_time)
				proxy.queries:append(6,string.char(proxy.COM_QUERY) .. 'update deployment_history set sql_state=null,finish_datetime=now() where oid_deployment_history=@i_oid_dh;',{resultset_is_needed = true})
			
				proxy.queries:append(7,string.char(proxy.COM_QUERY) .. 'insert into deployment_error(oid_deployment_history,error_DDL,error_no,error_message,execute_timestamp) values(@i_oid_dh ,"'..inj_query..'",'..res.raw:byte(2)+(res.raw:byte(3)*256)..',"'..string.format('%s', res.raw:sub(10))..'",now())',{resultset_is_needed = true})
				proxy.queries:append(8,string.char(proxy.COM_QUERY) .. InsDeplErrorCentro,{resultset_is_needed = true})
		
				proxy.queries:append(61,string.char(proxy.COM_QUERY) .. 'update deploymentdb.deployment_history_all set sql_state=null,finish_datetime=now() where oid_sub_deployment_history=@i_oid_dh and database_name=schema();',{resultset_is_needed = true})
		
		
			end
			
		end
		
	elseif inj.id == 4 then
		local res3 = assert(inj.resultset,"res3 is empty")
		if res3.query_status == proxy.MYSQLD_PACKET_ERR then
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
			-- print(out_string3 .. 'n')
			 
			proxy.response.type = proxy.MYSQLD_PACKET_ERR
			proxy.response.errmsg = "Insert into deployment_history table failure!"
			-- string.format('%s', res3.raw:sub(10))
			print("[Insert Deployment_history Table error]:"..string.format('%s', res3.raw:sub(10)));
			return proxy.PROXY_SEND_RESULT
		else 
			l_unit = l_unit +1
		end	
		
		return proxy.PROXY_IGNORE_RESULT
	elseif inj.id == 41 then
		return proxy.PROXY_IGNORE_RESULT
	elseif inj.id == 5 then
		local res31 = assert(inj.resultset,"res31 is empty")
		if res31.query_status == proxy.MYSQLD_PACKET_ERR then
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
				
	elseif inj.id == 6 then
		local res5 = assert(inj.resultset,"res5 is empty")
		if res5.query_status == proxy.MYSQLD_PACKET_ERR then
			error_result(string.format('%s', res5.raw:sub(10)),
						 res5.raw:byte(2)+(res5.raw:byte(3)*256),
						 inj.query:sub(2))
			return proxy.PROXY_SEND_RESULT				
		end
		return proxy.PROXY_IGNORE_RESULT
	elseif inj.id == 7 then
		local res6 = assert(inj.resultset,"res6 is empty")
		if res6.query_status == proxy.MYSQLD_PACKET_ERR then
			error_result(string.format('%s', res6.raw:sub(10)),
						 res6.raw:byte(2)+(res6.raw:byte(3)*256),
						 inj.query:sub(2))
			return proxy.PROXY_SEND_RESULT				
		end
		return proxy.PROXY_IGNORE_RESULT
	elseif inj.id == 8 then
		local res8 = assert(inj.resultset,"res8 is empty")
		if res8.query_status == proxy.MYSQLD_PACKET_ERR then
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






