local lapis = require("lapis")
local app = lapis.Application()

local database = require("luasql.sqlite3")
local env = database.sqlite3()

local sqlerror

--users={}
essen={"Bier", "alkfrei", "Frikadelle", 
	"Salzstangen", "KartSalat", "Sekt",
	"Wurst", "Wasser", "Sonstwas" }
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

function create_seatlist(vars)
  local res={}
  for i=1,4 do
    if vars.range[i][1] and vars.range[i][1]>0 then
      for j=vars.range[i][1],vars.range[i][2] do
        res[#res+1]=j
      end
    end
  end
  return res
end

function selectseat_widget(self,vars)
    local list= create_seatlist(vars)
    -- complete to 9 elements
    local missing= 9-#list
    for i=1,missing do 
      list[#list+1]=list[i]
    end
    local posinlist=1
    for i=1,#list do
      if vars.seat>=list[i] then 
        posinlist=i
      end
    end
    local pagestart=math.floor((posinlist-1)/8)*8
    if pagestart+8>#list then pagestart=#list-8 end
    return function()
      if sqlerror then text(sqlerror) end
      element("table", {width="100%"}, function()
      --'<table width="100%">'
          tr(function() 
                  td("Platz")
                  td(function()
                  	a({href=self:url_for("deliver")},"Liefern")
                    end)
                  td({align="center",bgcolor="red"},function()
                  	a({href=self:url_for("pay")},"Zahlen") 
                    end)
          end)
          for i=1,2 do
            tr(function()
            	for j=1,3 do
                  td({align="center",bgcolor="yellow"},function() 
                  	a({href=self:url_for("seat").."?seat="..tostring(list[pagestart+i*3-3+j])},tostring(list[pagestart+i*3-3+j]))
                     end)
                end
            end)
          end
          tr(function()
            	for j=1,2 do
                  td({align="center",bgcolor="yellow"},function() 
                  	a({href=self:url_for("seat").."?seat="..tostring(list[pagestart+9-3+j])},tostring(list[pagestart+9-3+j]))
                     end)
                end
                td(function()
       			local newstart=pagestart+9
       			if newstart>#list then newstart=1 end
                  	a({href=self:url_for("seatpage").."?start="..tostring(list[newstart])},">>")
                     end)
            end)
      end)
    end
end

function order_statistics(seat)
   local conn= env:connect("/var/local/meals/meals.db")
   local res= os.time()
   local open=0
   local query="select count(age) from orders where delivered is null and seat="..tostring(seat)
   local res,err= conn:execute(query)
   if not res then sqlerror=err 
   else
     local res2=res:fetch()
     open=res2 or 0
     res:close()
   end
   conn:close()
   return string.format("%d offene Bestellungen", open)
end

function selectmeal_widget(self,vars)
    return function()
      if sqlerror then text(sqlerror) end
--      p({style="font-size: x-large;"},function()
      element("table", {width="100%"}, function()
      --'<table width="100%">'
          tr(function() 
                  td({align="center",bgcolor="yellow"},function()
                  	a({href=self:url_for("seatpage")},tostring(vars.seat))
                    end)
                  td(function()
                  	a({href=self:url_for("deliver")},"Liefern")
                    end)
                  td({align="center",bgcolor="red"},function()
                  	a({href=self:url_for("pay")},"Zahlen") 
                    end)
          end)
          for i=1,3 do
            tr(function() 
            	for j=1,3 do
                  td({align="center",bgcolor="lightgreen"},function()
                  	a({href=self:url_for("order").."?meal="..tostring(i*3-3+j)},essen[i*3-3+j])
                  end)
                end
            end)
          end
      end)
      br()
      text(order_statistics(vars.seat))
--      end)
    end
end

function canonicalize(t)
  for i=1,4 do
    if t[i][1]>t[i][2] then
      t[i][1]=0
      t[i][2]=0
    elseif t[i][1]==0 then
      t[i][2]=0
    end
  end
  -- bubble sort
--  sqlerror="bubble "
  for i=4,2,-1 do
    for j=1,i-1 do
--      sqlerror=sqlerror..tostring(t[j][1]).."_"..tostring(t[j+1][1]).." "
      if (t[j+1][1]>0 and t[j][1]>t[j+1][1]) or (t[j][1]==0 and t[j+1][1]>0) then
--        sqlerror=sqlerror..tostring(t[j][1])..">"..tostring(t[j+1][1]).." "
        local x=t[j][1]
        t[j][1]=t[j+1][1]
        t[j+1][1]=x
        x=t[j][2]
        t[j][2]=t[j+1][2]
        t[j+1][2]=x
      end
    end
  end
  for i=1,3 do
    if t[i][2]>=t[i+1][1] and t[i+1][1]>0 then
      t[i][2]=t[i+1][1]-1
    end
  end
--  sqlerror=sqlerror..table_print(t)
end

app:get("seatpage", "/seatpage", function(self)
  local vars= getvars(ngx.var.remote_addr)
  if self.params.start then
    vars.seat= tonumber(self.params.start)
    setvars(ngx.var.remote_addr, vars)
  end
  return self:html(selectseat_widget(self,vars))
end)

app:get("login", "/login", function(self)
  local vars= getvars(ngx.var.remote_addr)
  vars.name= self.params.name or vars.name
  for i=1,4 do
    vars.range[i][1]= tonumber(self.params["from"..tostring(i)])
    vars.range[i][2]= tonumber(self.params["to"..tostring(i)])
  end
  canonicalize(vars.range)
  setvars(ngx.var.remote_addr, vars)
  return self:html(selectseat_widget(self,vars))
end)

app:get("seat", "/seat", function(self)
  local vars= getvars(ngx.var.remote_addr)
  vars.seat= self.params.seat or vars.seat
  setvars(ngx.var.remote_addr, vars)
  return self:html(selectmeal_widget(self,vars))  
end)

function store_order(name,seat,meal)
   local conn= env:connect("/var/local/meals/meals.db")
   local now= os.time()
   local query="insert into orders (age,name,seat,meal) "
     	.."values ("..tostring(now)..",'"..name.."',"..tostring(seat)..","..tostring(meal)..")"
   local res,err= conn:execute(query)
   if not res then sqlerror=err end
   conn:close()
end

app:get("order", "/order", function(self)
  local vars= getvars(ngx.var.remote_addr)
  local meal= tonumber(self.params.meal)
  store_order(vars.name,vars.seat,meal)
  return self:html(selectmeal_widget(self,vars))  
end)

app:get("deliver", "/deliver", function(self)
  return self:html(function()
  	h1("TBD")
  end)
end)

app:get("pay", "/pay", function(self)
  return self:html(function()
  	h1("TBD")
  end)
end)

function read_orders()
   local restable={}
--   local row={}
   local conn= env:connect("/var/local/meals/meals.db")
   local query="select age,name,meal from orders where ready is null order by age"
   local res,err= conn:execute(query)
   if not res then sqlerror=err 
   else
     local res2=res:fetch({},"a")
     while res2 do
       restable[#restable+1]=res2
       res2=res:fetch({},"a")
     end
     res:close()
   end
   conn:close()
   return restable
end

function format_number(x)
  local hours=math.floor(x/3600)
  x=x-hours*3600
  local min=math.floor(x/60)
  x=x-min*60
  return string.format("%d:%02d:%02d", hours, min, x)
end

app:get("kitchen", "/kitchen", function(self)
  local orders= read_orders()
  local now= os.time()
  self.title="Bestellungen"
  return self:html(function()
	if sqlerror then text(sqlerror) end
        element("table", {width="100%"}, function()
 	  for i=1,#orders do
              tr(function() 
                      td(format_number(now-orders[i].age))
                      td({align="center",bgcolor="yellow"},orders[i].name)
                      td({align="center",bgcolor="lightgreen"},essen[orders[i].meal])
                      td({align="center",bgcolor="green"},"Ok")
                 end)
          end
         end)
  	self.res:add_header("refresh","5")
  end)
end)

return app
