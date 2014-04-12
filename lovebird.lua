--
-- lovebird
--
-- Copyright (c) 2014, rxi
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local socket = require "socket"

local lovebird = { _version = "0.0.1" }

lovebird.inited = false
lovebird.host = "*"
lovebird.buffer = ""
lovebird.lines = {}
lovebird.pages = {}

lovebird.wrapprint = true
lovebird.timestamp = true
lovebird.allowhtml = true
lovebird.port = 8000
lovebird.whitelist = { "127.0.0.1", "localhost" }
lovebird.maxlines = 200
lovebird.refreshrate = .5

lovebird.pages["index"] = [[
<?lua
-- Handle console input
if req.parsedbody.input then
  local str = req.parsedbody.input
  xpcall(function() assert(loadstring(str))() end, lovebird.onError)
end
?>

<!doctype html>
<html>
  <head>
  <meta http-equiv="x-ua-compatible" content="IE=Edge"/>
  <title>lovebird</title>
  <style>
    body { 
      margin: 0px;
      font-size: 14px;
      font-family: helvetica, verdana, sans;
      background: #FFFFFF;
    }
    form {
      margin-bottom: 0px;
    }
    .timestamp {
      color: #909090;
    }
    .greybordered {
      margin: 12px;
      background: #F0F0F0;
      border: 1px solid #E0E0E0;
      border-radius: 3px;
    }
    #header {
      background: #101010;
      height: 25px;
      color: #F0F0F0;
      padding: 9px
    }
    #title {
      float: left;
      font-size: 20px;
    }
    #title a {
      color: #F0F0F0;
      text-decoration: none;
    }
    #title a:hover {
      color: #FFFFFF;
    }
    #version {
      font-size: 10px;
    }
    #status {
      float: right;
      font-size: 14px;
      padding-top: 4px;
    }
    #main a {
      color: #000000;
      text-decoration: none;
      background: #E0E0E0;
      border: 1px solid #D0D0D0;
      border-radius: 3px;
      padding-left: 2px;
      padding-right: 2px;
      display: inline-block;
    }
    #main a:hover {
      background: #D0D0D0;
      border: 1px solid #C0C0C0;
    }
    #console {
      position: absolute;
      top: 40px; bottom: 0px; left: 0px; right: 312px;
    }
    #input {
      position: absolute;
      margin: 10px;
      bottom: 0px; left: 0px; right: 0px;
    }
    #inputbox {
      width: 100%;
    }
    #output {
      overflow-y: scroll;
      position: absolute;
      margin: 10px;
      top: 0px; bottom: 36px; left: 0px; right: 0px;
    }
    #env {
      position: absolute;
      top: 40px; bottom: 0px; right: 0px;
      width: 300px;
    }
    #envheader {
      padding: 5px;
      background: #E0E0E0;
    }
    #envvars {
      position: absolute;
      left: 0px; right: 0px; top: 25px; bottom: 0px;
      margin: 10px;
      overflow-y: scroll;
      font-size: 12px;
    }
  </style>
  </head>
  <body>
    <div id="header">
      <div id="title">
        <a href="https://github.com/rxi/lovebird">lovebird</a>
        <span id="version"><?lua echo(lovebird._version) ?></span>
      </div>
      <div id="status">connected &#9679;</div>
    </div>
    <div id="main">
      <div id="console" class="greybordered">
        <div id="output"> <?lua echo(lovebird.buffer) ?> </div>
        <div id="input">
          <form method="post">
            <input id="inputbox" name="input" type="text"></input>
          </form>
        </div>
      </div>
      <div id="env" class="greybordered">
        <div id="envheader"></div>
        <div id="envvars"></div>
      </div>
    </div>
    <script>
      document.getElementById("inputbox").focus();

      var updateDivContent = function(id, content) {
        var div = document.getElementById(id); 
        if (div.innerHTML != content) {
          div.innerHTML = content;
          return true;
        }
        return false;
      }

      var getPage = function(url, onComplete, onFail) {
        var req = new XMLHttpRequest();
        req.onreadystatechange = function() {
          if (req.readyState != 4) return;
          if (req.status == 200) {
            if (onComplete) onComplete(req.responseText);
          } else {
            if (onFail) onFail(req.responseText);
          }
        }
        url += (url.indexOf("?") > -1 ? "&_=" : "?_=") + Math.random();
        req.open("GET", url, true);
        req.send();
      }

      /* Scroll output to bottom */
      var scrolloutput = function() {
        var div = document.getElementById("output"); 
        div.scrollTop = div.scrollHeight;
      }
      scrolloutput()

      /* Output buffer and status */
      var refreshOutput = function() {
        getPage("/buffer", function(text) {
          updateDivContent("status", "connected &#9679;");
          if (updateDivContent("output", text)) {
            scrolloutput();
          }
        },
        function(text) {
          updateDivContent("status", "disconnected &#9675;");
        });
      }
      setInterval(refreshOutput, <?lua echo(lovebird.refreshrate) ?> * 1000);

      /* Environment variable view */
      var envPath = "";
      var refreshEnv = function() {
        getPage("/env.json?p=" + envPath, function(text) { 
          var json = eval("(" + text + ")");

          /* Header */
          var html = "<a href='#' onclick=\"setEnvPath('')\">env</a>";
          var acc = "";
          var p = json.path != "" ? json.path.split(".") : [];
          for (var i = 0; i < p.length; i++) {
            acc += "." + p[i];
            html += " <a href='#' onclick=\"setEnvPath('" + acc + "')\">" +
                    p[i] + "</a>";
          }
          updateDivContent("envheader", html);

          /* Variables */
          var html = "<table>";
          for (var i = 0; json.vars[i]; i++) {
            var x = json.vars[i];
            var k = x.key;
            if (x.type == "table") {
              var p = "setEnvPath('" + json.path + "." + x.key + "');";
              k = "<a href='#' onclick=\"" + p + "\">" + k + "</a>";
            }
            html += "<tr><td>" + k + "</td><td>" + x.value + "</td></tr>";
          }
          html += "</table>";
          updateDivContent("envvars", html);
        });
      }
      var setEnvPath = function(p) { 
        envPath = p.replace(/^\.*/, "");
        refreshEnv();
      }
      setInterval(refreshEnv, <?lua echo(lovebird.refreshrate) ?> * 1000);
    </script>
  </body>
</html>
]]


lovebird.pages["buffer"] = [[ <?lua echo(lovebird.buffer) ?> ]]


lovebird.pages["env.json"] = [[
  <?lua 
    local t = _G
    local p = req.parsedurl.query.p or ""
    if p ~= "" then
      for x in p:gmatch("[^%.]+") do
        t = t[x]
      end
    end
  ?>
  {
    "path": "<?lua echo(p) ?>",
    "vars": [
      <?lua 
        local keys = {}
        for k in pairs(t) do table.insert(keys, k) end
        table.sort(keys)
        for _, k in pairs(keys) do 
          local v = t[k]
      ?>
        { 
          "key": "<?lua echo(k) ?>",
          "value": <?lua echo( 
                            string.format("%q",
                              lovebird.truncate(
                                lovebird.htmlescape(
                                  tostring(v)), 26))) ?>,
          "type": "<?lua echo(type(v)) ?>",
        },
      <?lua end ?>
    ]
  }
]]



local loadstring = loadstring or load

local map = function(t, fn)
  local res = {}
  for k, v in pairs(t) do res[k] = fn(v) end
  return res
end

local find = function(t, value)
  for k, v in pairs(t) do
    if v == value then return k end
  end
end

local trace = function(...)
  print("[lovebird] " .. table.concat(map({...}, tostring), " "))
end

local unescape = function(str)
  local f = function(x) return string.char(tonumber("0x"..x)) end
  return (str:gsub("%+", " "):gsub("%%(..)", f))
end



function lovebird.init()
  lovebird.server = assert(socket.bind(lovebird.host, lovebird.port))
  lovebird.addr, lovebird.port = lovebird.server:getsockname()
  lovebird.server:settimeout(0)
  if lovebird.wrapprint then
    local oldprint = print
    print = function(...)
      oldprint(...)
      lovebird.print(...)
    end
  end
  lovebird.inited = true
end


function lovebird.template(str, env)
  env = env or {}
  local keys, vals = {}, {}
  for k, v in pairs(env) do 
    table.insert(keys, k)
    table.insert(vals, v)
  end
  local f = function(x) return string.format(" echo(%q)", x) end
  str = ("?>"..str.."<?lua"):gsub("%?>(.-)<%?lua", f)
  str = "local echo, " .. table.concat(keys, ",") .. " = ..." .. str
  local output = {}
  local echo = function(str) table.insert(output, str) end
  assert(loadstring(str))(echo, unpack(vals))
  return table.concat(map(output, tostring))
end


function lovebird.parseurl(url)
  local res = {}
  res.path, res.search = url:match("/([^%?]*)%??(.*)")
  res.query = {}
  for k, v in res.search:gmatch("([^&^?]-)=([^&^#]*)") do
    res.query[k] = unescape(v)
  end
  return res
end


function lovebird.htmlescape(str)
  return str:gsub("<", "&lt;")
end


function lovebird.truncate(str, len)
  if #str < len then
    return str
  end
  return str:sub(1, len - 3) .. "..."
end


function lovebird.print(...)
  local str = table.concat(map({...}, tostring), " ")
  if not lovebird.allowhtml then
    str = lovebird.htmlescape(str)
  end
  if lovebird.timestamp then
    str = os.date('<span class="timestamp">[%H:%M:%S]</span> ') .. str
  end
  table.insert(lovebird.lines, str)
  if #lovebird.lines > lovebird.maxlines then
    table.remove(lovebird.lines, 1)
  end
  lovebird.buffer = table.concat(lovebird.lines, "<br>")
end


function lovebird.onError(err)
  trace("ERROR:", err)
end


function lovebird.onRequest(req, client)
  local page = req.parsedurl.path
  page = page ~= "" and page or "index"
  -- Handle "page not found"
  if not lovebird.pages[page] then 
    return "HTTP/1.1 404\r\nContent-Type: text/html\r\n\r\nBad page"
  end
  -- Handle existent page
  return "HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n" ..
         lovebird.template(lovebird.pages[page],
                           { lovebird = lovebird, req = req })
end


function lovebird.onConnect(client)
  -- Create request table
  local requestptn = "(%S*)%s*(%S*)%s*(%S*)"
  local req = {}
  req.socket = client
  req.addr, req.port = client:getsockname()
  req.request = client:receive()
  req.method, req.url, req.proto = req.request:match(requestptn)
  req.headers = {}
  while 1 do
    local line = client:receive()
    if not line or #line == 0 then break end
    local k, v = line:match("(.-):%s*(.*)$")
    req.headers[k] = v
  end
  if req.headers["Content-Length"] then
    req.body = client:receive(req.headers["Content-Length"])
  end
  -- Parse body
  req.parsedbody = {}
  if req.body then
    for k, v in req.body:gmatch("([^&]-)=([^&^#]*)") do
      req.parsedbody[k] = unescape(v)
    end
  end
  -- Parse request line's url
  req.parsedurl = lovebird.parseurl(req.url)
  -- Handle request; get data to send
  local data, index = lovebird.onRequest(req), 0
  -- Send data
  while index < #data do
    index = index + client:send(data, index)
  end
  -- Clear up
  client:close()
end


function lovebird.update()
  if not lovebird.inited then lovebird.init() end 
  local client = lovebird.server:accept()
  if client then
    client:settimeout(2)
    local addr = client:getsockname()
    if not lovebird.whitelist or find(lovebird.whitelist, addr) then 
      xpcall(function() lovebird.onConnect(client) end, lovebird.onError)
    else
      trace("got non-whitelisted connection attempt: ", addr)
      client:close()
    end
  end
end


return lovebird
