local lapis = require("lapis")
local app = lapis.Application()

local database = require("luasql.sqlite3")
local env = database.sqlite3()

local sqlerror

--users={}
essen={"Bier", "alkfrei", "Frikadelle", 
	"Salzstangen", "KartSalat", "Sekt",
	"Wurst", "Wasser", "Zurück" }
preis={1.00, 1.00, 2.00,
	0.5, 3.00, 4.00,
	1.5, 1.5, 0.00 }

function getvars(ip)
   local conn= env:connect("/var/local/meals/meals.db")
   local curs,err=conn:execute("select name,from1,to1,from2,to2,from3,to3,from4,to4,seat "
   	.."from users where ip='"..ip.."'")
   if not curs then sqlerror=err end
   local res=curs and curs:fetch({},"a")
   local x={}
   if not res then
     x= {name=ip, range={{0,0},{0,0},{0,0},{0,0}}, seat=1 }
     local query="insert into users (name,from1,to1,from2,to2,from3,to3,from4,to4,seat,ip) "
     	.."values ('"..ip.."',0,0,0,0,0,0,0,0,1,'"..ip.."')"
--     print(query)
     local res,err= conn:execute(query)
     if not res then sqlerror=err end
   else
     x= {name=res.name, range={{res.from1,res.to1},{res.from2,res.to2},{res.from3,res.to3},{res.from4,res.to4}}, seat=res.seat}
   end
   if curs then curs:close() end
   conn:close()
   return x
end

function setvars(ip,vars)
   local conn= env:connect("/var/local/meals/meals.db")
   local query= "update users set name='"..vars.name.."',from1="..tostring(vars.range[1][1])
   	..",to1="..tostring(vars.range[1][2])
   	..",from2="..tostring(vars.range[2][1])
   	..",to2="..tostring(vars.range[2][2])
   	..",from3="..tostring(vars.range[3][1])
   	..",to3="..tostring(vars.range[3][2])
   	..",from4="..tostring(vars.range[4][1])
   	..",to4="..tostring(vars.range[4][2])
   	..",seat="..tostring(vars.seat) 
   	.." where ip='"..ip.."'"
   local res,err= conn:execute(query)
   if not res then sqlerror=err end
   conn:close()
end

app:get("/", function(self)
  return self:html(function()
    local vars= getvars(ngx.var.remote_addr)
--    h2(text("Welcome "..ngx.var.remote_addr))
    form({action=self:url_for("login")}, function()
        text("Name")
    	input{type="text", name="name", value=vars.name}
    	br()
    	for i=1,4 do
          input{type="number", size="3", maxlength="3", name="from"..tostring(i), value=tostring(vars.range[i][1]), min=0, max=120}
          text("-")
          input{type="number", size="3", maxlength="3", name="to"..tostring(i), value=tostring(vars.range[i][2]), min=0, max=120}
          br()
    	end
    	input{type="submit", value="Start"}
      end)
  end)
end)

app:get("/y", function(self)
  return self:html(function()
    a{href="test/2", "test"}
  end)
end)

app:get("/x", function(self)
  return self:html(function()
    text(table_print(_G,3))
    p()
    text(table_print(self,3))
  end)
end)


app:get("/button", function(self)
  return self:html(function()
    a{href="test/2", "test"}
  end)
--  return "Welcome to Lapis " .. require("lapis.version")
end)

function table_print (tt,depth)
  local res=""
  if type(tt) == "table" and (not depth or depth>1) then
    res=res.."{"
    if depth then depth=depth-1 end
    for key, value in pairs (tt) do
      res=res.."["..table_print(key,depth).."]="..table_print(value,depth).." "
    end
    return res.."}"
  else
    return tostring(tt)
  end
end

function selectseat_widget(self,vars)
    if vars.seat<5 then vars.seat=5 end
    return function()
      if sqlerror then text(sqlerror) end
      element("table", {width="100%"}, function()
      --'<table width="100%">'
          tr(function() 
                  td("Platz")
                  td("Liefern")
                  td("Zahlen") 
          end)
          for i=1,3 do
            tr(function() 
                  td(function() 
                  	a({href=self:url_for("seat").."?seat="..tonumber(vars.seat+i*3-7)},tonumber(vars.seat+i*3-7))
                     end)
                  td(function() 
                  	a({href=self:url_for("seat").."?seat="..tonumber(vars.seat+i*3-6)},tonumber(vars.seat+i*3-6))
                     end)
                  td(function() 
                  	a({href=self:url_for("seat").."?seat="..tonumber(vars.seat+i*3-5)},tonumber(vars.seat+i*3-5))
                     end)
            end)
          end
      end)
    end
end

function selectmeal_widget(self,vars)
    return function()
      if sqlerror then text(sqlerror) end
      element("table", {width="100%"}, function()
      --'<table width="100%">'
          tr(function() 
                  td(tonumber(vars.seat))
                  td("Liefern")
                  td("Zahlen") 
          end)
          for i=1,3 do
            tr(function() 
                  td(function()
                  	a({href=self:url_for("order").."?meal="..tonumber(i*3-2)},essen[i*3-2])
                  end)
                  td(function()
                  	a({href=self:url_for("order").."?meal="..tonumber(i*3-1)},essen[i*3-1])
                  end)
                  td(function()
                  	a({href=self:url_for("order").."?meal="..tonumber(i*3-0)},essen[i*3-0])
                  end)
            end)
          end
      end)
    end
end

app:get("login", "/login", function(self)
  local vars= getvars(ngx.var.remote_addr)
  vars.name= self.params.name or vars.name
  for i=1,4 do
    vars.range[i][1]= tonumber(self.params["from"..tostring(i)])
    vars.range[i][2]= tonumber(self.params["to"..tostring(i)])
  end
  setvars(ngx.var.remote_addr, vars)
  return self:html(selectseat_widget(self,vars))
end)

app:get("seat", "/seat", function(self)
  local vars= getvars(ngx.var.remote_addr)
  vars.seat= self.params.seat or vars.seat
  setvars(ngx.var.remote_addr, vars)
  return self:html(selectmeal_widget(self,vars))  
end)

app:get("order", "/order", function(self)
  local vars= getvars(ngx.var.remote_addr)
  local meal= self.params.meal
  return self:html(function()
  	h2("Meal "..tonumber(meal))--.." for "..tonumber(vars.seat).." by "..vars.name)
  	text(table_print(vars))
  end)
end)

return app
