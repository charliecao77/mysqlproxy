
-- without key local is Global Variable
local tokenizer = require("proxy.tokenizer")
local DEBUG = os.getenv('DEBUG') or 0

DEBUG = DEBUG + 0
DEBUG = 5

TABLE_LIST=""
INFO_TIME=os.date('%Y-%m-%d %H:%M:%S')
SYSTEM_DB='information_schema,mysql,performance_schema'

local tot_q = 0
local l_Stoplog=""
local l_database=""
local l_unit=1

function print_debug(msg,level)
  level = level or 1 
  if DEBUG >= level then
    print(msg)
  end
end

function connect_server()
  print_debug(INFO_TIME..":[INFO ] Working ON Server: " .. proxy.global.backends[1].dst.name)
end

-- Function: min()
-- find out the minimal value in a table{}
function min(a)
  local t = a
  local key, min = 1, t[1]
  for k, v in ipairs(t) do
    if t[k] < min then
        key, min = k, v
    end
  end
  return min
end

-- Function: max()
-- find out the maximal value in a table{}
function max(a)
  local values = {}
  for k,v in pairs(a) do
    values[#values+1] = v
  end
  table.sort(values) -- automatically sorts lowest to highest
  return values[#values]
end

-- Function: trim()
-- remove the space around the string
function trim(s)
   local i1,i2 = string.find(s,'^%s*')
   if i2 >= i1 then
      s = string.sub(s,i2+1)
   end
   local i1,i2 = string.find(s,'%s*$')
   if i2 >= i1 then
      s = string.sub(s,1,i1-1)
   end
   return s
end
-- Function: StripSQL()
-- Strip a SQL statement return a table list
function StripSQL(sql)
  SQL_STR = string.gsub(sql:upper(),'`','')
  i,j = string.find(SQL_STR,"FROM")
  if i == nil then
    -- print("no from in SQL")
    return
  end
  start_point=j+1
  m1,n1 = string.find(SQL_STR,"WHERE")
  m2,n2 = string.find(SQL_STR,"GROUP BY")
  m3,n3 = string.find(SQL_STR,"ORDER BY")
  m4,n4 = string.find(SQL_STR,"LIMIT")
  if m1==nil then m1 = 99999999 end
  if m2==nil then m2 = 99999999 end
  if m3==nil then m3 = 99999999 end
  if m4==nil then m4 = 99999999 end
  end_point=min({m1,m2,m3,m4})-1
  SQL_SUB_STR=trim(string.sub(SQL_STR,start_point,end_point))
  --print('RoughlyTableList:' .. SQL_SUB_STR)
  TABLE_LIST = TableList(SQL_SUB_STR)
  --print('TABLE_LIST:' .. TABLE_LIST)
  return TABLE_LIST
end

--[[ Function: TableList()
     accept sql string between 'from' and 'where/group by/order by/limit'
     return a string which formed as a database name as prefix db.t1,db,t2..
--]]
function TableList(sql)
  local mytable = {}
  local CURR_DB = proxy.connection.client.default_db:upper()
  local SQL_STR = trim(sql:upper())
  local TBLIST = ""
  local TBNAME = ""
    while ( string.len(SQL_STR)>0 )
    do
      m,n = string.find(SQL_STR," ")
      if m == nil then  -- Only One Table
        TBLIST = SQL_STR
        t1,f1 = string.find(TBLIST,'%.') --% is escape character
        if t1 == nil then
          TBLIST = '"'..CURR_DB..'.'..TBLIST..'"'
          table.insert(mytable,TBLIST)
         -- return mytable
          return TBLIST
        end 
        TBLIST='"'..TBLIST..'"'
       -- return mytable 
        return TBLIST 
      end
      
      TBNAME = string.sub(SQL_STR,1,m-1)
      t,f = string.find(TBNAME,'%.')
      if t == nil then
        TBNAME = '"'..CURR_DB..'.'..TBNAME..'"'
      else
        TBNAME = '"'..TBNAME..'"'
      end
      if TBLIST == "" then
        TBLIST = TBNAME
      else
        TBLIST = TBLIST .. "," .. TBNAME
      end
      SQL_STR = trim(string.sub(SQL_STR,n+1))
      m,n = string.find(SQL_STR," JOIN ")
      if m == nil then
        SQL_STR = ""
        return TBLIST
      end
      SQL_STR = trim(string.sub(SQL_STR,n+1))
    end
end

function error_result(msg,code,state)
  proxy.response = {
    type = proxy.MYSQL_PACKET_ERR,
    errmsg = msg,
    errcode = code,
    sqlstate = state,
  }
  return proxy.PROXY_SEND_RESULT
end

function simple_dataset(header,message)
  proxy.response.type = proxy.MYSQL_PACKET_OK
  proxy.response.resultset ={
    fields = {
      {type = proxy.MYSQL_TYPE_STRING, name = header}
    },
    rows = {
      {message}
    }
  }
end

function proxy.global.make_dataset(header,dataset)
  proxy.response.type = proxy.MYSQL_PACKET_OK
  proxy.response.resultset = {
    fields = {},rows ={}
  }
  for i,v in pairs (header) do
    table.insert(
      proxy.response.resultset.fields,
        {type = proxy.MYSQL_TYPE_STRING, name = v }
    )
  end
  for i,v in pairs (dataset) do
    table.insert(
      proxy.response.resultset.rows,v
    )
  end
  return proxy.PROXY_SEND_RESULT
end

function affected_rows(rows,id)
  proxy.response = {
    type = proxy.MYSQL_PACKET_OK,
    affected_rows = rows,
    insert_id = id,
  }
  return proxy.PROXY_SEND_RESULT
end


print_debug(INFO_TIME..':[INFO ] Start:-----------------------------------------') 
function read_query(packet)
  if packet:byte() ~= proxy.COM_QUERY then return end
  if packet:byte() == proxy.COM_QUERY then
    local sql_state=string.sub(packet,2)
    print_debug('[INFO ] PREVIOUS DB: '..l_database)
    print_debug('[INFO ]  CURRENT DB: '..proxy.connection.client.default_db)
    if l_database ~= proxy.connection.client.default_db then
      l_unit=1
      l_database = proxy.connection.client.default_db
    end
   
   if string.match(SYSTEM_DB,proxy.connection.client.default_db) then
     proxy.response.type = proxy.MYSQLD_PACKET_ERR
     proxy.response.errmsg = "Use a Database except information_schema and mysql to apply for your states, Current DB is ["..
                              proxy.connection.client.default_db..
                              "]"
     print_debug('[INFO ] Waiting to set a DB, '..
                 'No permission on system DB(information_schema,mysql)')
     return proxy.PROXY_SEND_RESULT
   end	
     
		
   TABLE_LIST = StripSQL(packet)
   if TABLE_LIST == nil then TABLE_LIST="Empty." end
   print_debug('[INFO ] ClientSQL TABLES: '..TABLE_LIST)

   if string.match(packet:upper(),'STANDARD_IMS_PROFILE') then
     proxy.response.type = proxy.MYSQLD_PACKET_ERR
     proxy.response.errmsg = "TABLE NOT ALLOW TO REVIEW!"
     return proxy.PROXY_SEND_RESULT
   end

   -- prepare the value for the deployment_history log.
   local connect_info ="[MYSQL-VERSION]: "..proxy.connection.server.mysqld_version..
			";[SERVER]:"..proxy.connection.server.dst.address..
			";[THREAD_ID]:"..proxy.connection.server.thread_id..
			";[PROXY]:"..proxy.connection.client.dst.address..
			";[Client addr]:"..proxy.connection.client.src.address..
			";[default_db]:"..proxy.connection.client.default_db..
			";[client]:"..proxy.connection.client.username
   print_debug('[INFO ] CONNECTION INFO: '..connect_info)
   --local login_username=proxy.connection.client.username
   sql_limited_tables="select upper(concat('{',group_concat(concat('\"',table_schema,'.',table_name,'\"')),'}'))"..
                            " from deploymentdb.limit_access_table_list "..
                            " where active='Y' "..
                            " group by ''; "

   local sql_client = packet:sub(2)
   -- Run the query in the Queue 
   -- first in first run, ignore the number.
   proxy.queries:append(2,string.char(proxy.COM_QUERY)..sql_limited_tables,{resultset_is_needed = true})
   proxy.queries:append(1,packet,{resultset_is_needed = true})


--[[		 

   local query1 = packet:sub(2)
   --proxy.queries:append(1,query1,{resultset_is_needed = true})
   local tokens = tokenizer.tokenize(query1)
   -- only look at the first one in the tokens.
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
       --	proxy.queries:append(4,string.char(proxy.COM_QUERY) .. InsertDeplHis,{resultset_is_needed = true})
       --	proxy.queries:append(41,string.char(proxy.COM_QUERY) .. CurrentOidDeplHis,{resultset_is_needed = true})
       --	proxy.queries:append(5,string.char(proxy.COM_QUERY) .. InsertDeplHisCentro,{resultset_is_needed = true})
			
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
--]]
  return proxy.PROXY_SEND_QUERY
  end
end


-- convert string to table
function stringToTable(sep,d)
   -- '[^,]' means "everything but the comma, the + sign means "one or more characters".
   local t={}
   for word in string.gmatch(sep,'([^'..d..']+)') do
     table.insert(t,word)
   end
   return t
end

function verify_limited_table(client,db)
  local ll_client=stringToTable(client,',')
  local ll_db=db
  local ll_Tab=""
  for index,data in ipairs(ll_client) do
    if string.match(ll_db,data) then
      print_debug('[INFO ] Find Limited Table: '..data,5)
      if ll_Tab=="" then 
        ll_Tab=data
      else
        ll_Tab=ll_Tab..','..data
      end
    end
  end
      print_debug('[INFO ] ll_Tab= '..ll_Tab,5)
  if ll_Tab==nil or ll_Tab=="" then ll_Tab="empty" end
  return ll_Tab
end

-- Seems only one inject Query result can be show 
-- So, ignore all backend Query 
function read_query_result(inj)
  if inj.id == 1 then
    print_debug('[INFO ] Client SQL: '..inj.query,5)
    print_debug('[INFO ] DB Limited Tables: '..DB_LIMITED_TABLES,5)
    print_debug('[INFO ] SQL Tables: '..TABLE_LIST,5)
    local limited_tables=verify_limited_table(TABLE_LIST,DB_LIMITED_TABLES) 
    print_debug('[INFO ] limited table list: '..limited_tables,5)
    if limited_tables ~= "empty" then
    --if limited_tables ~= "" then
      proxy.response.type = proxy.MYSQLD_PACKET_ERR
      proxy.response.errmsg = "Find Out Limited Table:"..limited_tables
      return proxy.PROXY_SEND_RESULT

    end 
    --return proxy.PORXY_SEND_RESULT
  
  elseif inj.id == 2 then
    for row in inj.resultset.rows do
      DB_LIMITED_TABLES=row[1]
    end
    print_debug('[INFO ] Backend SQL: '..inj.query,6)
    print_debug('[INFO ] Backend SQL Result: '..DB_LIMITED_TABLES,6)

    return proxy.PROXY_IGNORE_RESULT
    
  end

end

