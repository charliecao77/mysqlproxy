require("mysql.tokenizer")

local fh = io.open("./proxy_query.log", "a+")
fh:setvbuf('line',4096)
local the_query = "";
local seqno = 0;

function read_query( packet )
    if string.byte(packet) == proxy.COM_QUERY then
        seqno = seqno + 1
        the_query = (string.gsub(string.gsub(string.sub(packet, 2), "%s%s*", ' '), "^%s*(.-)%s*$", "%1"))
        fh:write(string.format("%s %09d %09d : %s (%s) -- %s\n",
            os.date('%Y-%m-%d %H:%M:%S'),
            proxy.connection.server.thread_id,
            seqno,
            proxy.connection.client.username,
            proxy.connection.client.default_db,
            the_query))
        fh:flush()
        return proxy.PROXY_SEND_QUERY
    else
        query = ""
    end
end
