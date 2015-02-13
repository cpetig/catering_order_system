local lapis = require("lapis")
local app = lapis.Application()
local encoding = require("lapis.util.encoding")

local database = require("luasql.sqlite3")
local env = database.sqlite3()

local sqlerror

local columns=3
local rows=3
local database="/var/local/meals/meals.db"
local rangesize=4
local elems_page = columns*rows-1
local fontsize=8
local fontsize_meals=fontsize-1
local fontsize_seats=fontsize+1
local fontsize_pay=fontsize+1

--users={}
essen={"Fl. Rotwein", "Fl. Weißwein", "Glas Rotwein", 
	"Glas Weißwein", "Fl. Sekt", "Glas Sekt",
	"Pils", "Kölsch", "Alt",
	"alkfrei", "Korn", "Weinbrand",
	"Tequila", "Klopfer", "Shot",
	"Fl. Wasser", "Glas Wasser", "Cola",
	"Fanta", "Sprite", "O-Saft",
	"A-Saft", "Tee", "Kaffee",
	
	"Wurst+Brot", "Wurst+Kart.","Schnitzel+Brot",
	"Schnitzel+Kart.","Frikad.+Brot","Frikad.+Kart.",
	"Gulaschsuppe", "Rote Grütze", "Chips",
	"Salzstangen", "Brezel"
	 }
preis={8, 8, 2,
	2,7,2.5,
	2.5,2.5,2.5,
	2.5,1,1,
	1,1,1,
	0.5,2.5,1,
	1,1,1,
	1,1,1,
	
	3,4.5,4,
	5.5,3.5,5,
	3,2.5,1,
	1,1
 }

function getvars(ip)
   local conn= env:connect(database)
   local curs,err=conn:execute("select name,from1,to1,from2,to2,from3,to3,from4,to4,seat,mealpage "
   	.."from users where ip='"..ip.."'")
   if not curs then sqlerror=err end
   local res=curs and curs:fetch({},"a")
   local x={}
   if not res then
     x= {name=ip, range={{0,0},{0,0},{0,0},{0,0}}, seat=1, mealpage=1 }
     local query="insert into users (name,from1,to1,from2,to2,from3,to3,from4,to4,seat,ip,mealpage) "
     	.."values ('"..ip.."',0,0,0,0,0,0,0,0,1,'"..ip.."',1)"
--     print(query)
     local res,err= conn:execute(query)
     if not res then sqlerror=err end
   else
     x= {name=res.name, range={{res.from1,res.to1},{res.from2,res.to2},{res.from3,res.to3},{res.from4,res.to4}}, 
     	seat=res.seat, mealpage=res.mealpage}
   end
   if curs then curs:close() end
   conn:close()
   return x
end

function setvars(ip,vars)
   local conn= env:connect(database)
   local query= "update users set name='"..vars.name.."',from1="..tostring(vars.range[1][1])
   	..",to1="..tostring(vars.range[1][2])
   	..",from2="..tostring(vars.range[2][1])
   	..",to2="..tostring(vars.range[2][2])
   	..",from3="..tostring(vars.range[3][1])
   	..",to3="..tostring(vars.range[3][2])
   	..",from4="..tostring(vars.range[4][1])
   	..",to4="..tostring(vars.range[4][2])
   	..",seat="..tostring(vars.seat) 
   	..",mealpage="..tostring(vars.mealpage) 
   	.." where ip='"..ip.."'"
   local res,err= conn:execute(query)
   if not res then sqlerror=err end
   conn:close()
end

app:get("/", function(self)
  self.title="Login"
  return self:html(function()
    local vars= getvars(ngx.var.remote_addr)
   element("font", {size=fontsize}, function()
    form({action=self:url_for("login")}, function()
        text("Name")
    	input{type="text", name="name", value=vars.name}
    	br()
    	for i=1,rangesize do
          input{type="number", size="3", maxlength="3", name="from"..tostring(i), value=tostring(vars.range[i][1]), min=0, max=120}
          text("-")
          input{type="number", size="3", maxlength="3", name="to"..tostring(i), value=tostring(vars.range[i][2]), min=0, max=120}
          br()
    	end
    	input{type="submit", value="Start"}
      end)
    end)
--      self.res:add_header("HandheldFriendly", "true")
  end)
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
  for i=1,rangesize do
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
    local seatcols= 2*columns
    local elems_page= seatcols*rows
    -- complete to 9 elements
    local missing= seatcols*rows-#list
    for i=1,missing do 
      list[#list+1]=list[i]
    end
    local posinlist=1
    for i=1,#list do
      if vars.seat>=list[i] then 
        posinlist=i
      end
    end
    local pagestart=math.ceil((posinlist-1)/(elems_page))*(elems_page)
    -- pagestart starts at 0
    if pagestart+elems_page>#list then pagestart=#list-(elems_page) end
    self.title="Platzwahl"
--    self.res:add_header("HandheldFriendly", "true")
--    self.res:add_header("viewport", "width=device-width, maximum-scale=1.0, user-scalable=yes")
    return function()
      --text(pagestart)text(posinlist)text(table_print(list))
      if sqlerror then text(sqlerror) end
     element("font", {size=fontsize_seats}, function()
      element("table", {width="100%"}, function()
      --'<table width="100%">'
          tr(function() 
                  td({align="center",colspan="2"},"Platz")
                  td({align="center",colspan="2"},function()
                  	a({href=self:url_for("deliver")},"Liefern")
                    end)
                  td({align="center",colspan="2",bgcolor="red"},function()
                  	a({href=self:url_for("pay")},"Zahlen") 
                    end)
          end)
          for i=1,rows-1 do
            tr(function()
            	for j=1,seatcols do
                  td({align="center",bgcolor="yellow"},function() 
                  	a({href=self:url_for("seat").."?seat="..tostring(list[pagestart+i*seatcols-seatcols+j])},tostring(list[pagestart+i*seatcols-seatcols+j]))
                     end)
                end
            end)
          end
          tr(function()
            	for j=1,seatcols-1 do
                  td({align="center",bgcolor="yellow"},function() 
                  	a({href=self:url_for("seat").."?seat="..tostring(list[pagestart+rows*seatcols-seatcols+j])},tostring(list[pagestart+rows*seatcols-seatcols+j]))
                     end)
                end
                td({align="center"},function()
       			local newstart=pagestart+seatcols*rows
       			--newstart starts at 1
       			if newstart>#list then newstart=1
       			elseif newstart+elems_page>#list then newstart=#list-(elems_page)+1
       			end
                  	a({href=self:url_for("seatpage").."?start="..tostring(list[newstart])},">>")
                     end)
            end)
      end)
     end)
--      self.res:add_header("HandheldFriendly", "true")
    end
end

function order_statistics(seat)
   local conn= env:connect(database)
   local res= os.time()
   local open=0
   local query="select meal,rowid,ready from orders where delivered is null and seat="..tostring(seat).." order by age"
   local res,err= conn:execute(query)
   local restable={}
   if not res then sqlerror=err 
   else
     local res2=res:fetch({},"a")
     while res2 do
       restable[#restable+1]={ meal=res2.meal, rowid=res2.rowid, ready=res2.ready }
       res2=res:fetch({},"a")
     end
     res:close()
   end
   conn:close()
   return restable
   --string.format("%d offene Bestellungen", open)
end

function selectmeal_widget(self,vars)
    local pagestart=math.ceil((vars.mealpage-1)/(elems_page))*(elems_page)
    -- pagestart starts at 0
    if pagestart+elems_page>#essen then pagestart=#essen-(elems_page) end
    return function()
      if sqlerror then text(sqlerror) end
--      p({style="font-size: x-large;"},function()
     element("font", {size=fontsize_meals}, function()
      element("table", {width="100%"}, function()
      --'<table width="100%">'
          tr(function() 
                  td({align="center",bgcolor="yellow"},function()
                  	a({href=self:url_for("seatpage")},tostring(vars.seat))
                    end)
                  td({align="center"},function()
                  	a({href=self:url_for("deliver")},"Liefern")
                    end)
                  td({align="center",bgcolor="red"},function()
                  	a({href=self:url_for("pay")},"Zahlen") 
                    end)
          end)
          for i=1,rows-1 do
            tr(function() 
            	for j=1,columns do
                  td({align="center",bgcolor="lightgreen"},function()
                  	a({href=self:url_for("order").."?meal="..tostring(pagestart+i*columns-columns+j)},essen[pagestart+i*columns-columns+j])
                  end)
                end
            end)
          end
          tr(function() 
              for j=1,columns-1 do
                td({align="center",bgcolor="lightgreen"},function()
                      a({href=self:url_for("order").."?meal="..tostring(pagestart+rows*columns-columns+j)},essen[pagestart+rows*columns-columns+j])
                end)
              end
              td({align="center"},function()
                      local newstart=pagestart+columns*rows
                      --newstart starts at 1
                      if newstart>#essen then newstart=1
                      elseif newstart+elems_page>#essen then newstart=#essen-(elems_page)+1
                      end
                      a({href=self:url_for("mealpage").."?start="..tostring(newstart)},">>")
                   end)
          end)
          local stats= order_statistics(vars.seat)
          for i=1,#stats do
            tr(function()
              td(essen[stats[i].meal])
              td(string.format("%.2f€", preis[stats[i].meal]))
              if stats[i].ready then td("wartet")
              else
              	td(function()
              	   a({href=self:url_for("cancel").."?rowid="..tostring(stats[i].rowid)}, "Storno")
              	end)
              end
            end) 
          end
--          text(table_print(stats))
      end)
     end)
      --br()
      --text(order_statistics(vars.seat))
--      end)
      self.options.content_type="text/html; charset=utf-8"
    end
end

function canonicalize(t)
  for i=1,rangesize do
    if t[i][1]>t[i][2] then
      t[i][1]=0
      t[i][2]=0
    elseif t[i][1]==0 then
      t[i][2]=0
    end
  end
  -- bubble sort
--  sqlerror="bubble "
  for i=rangesize,2,-1 do
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
  for i=1,rangesize-1 do
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

app:get("mealpage", "/mealpage", function(self)
  local vars= getvars(ngx.var.remote_addr)
  if self.params.start then
    vars.mealpage= tonumber(self.params.start)
    setvars(ngx.var.remote_addr, vars)
  end
  return self:html(selectmeal_widget(self,vars))
end)

app:get("login", "/login", function(self)
  local vars= getvars(ngx.var.remote_addr)
  vars.name= self.params.name or vars.name
  for i=1,rangesize do
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
   local conn= env:connect(database)
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

function read_deliveries(vars)
   local seats = "seat between "..tostring(vars.range[1][1]).." and "..tostring(vars.range[1][2])
   for i=2,rangesize do
     if vars.range[i][1]>0 then
       seats= seats.." or seat between "..tostring(vars.range[i][1]).." and "..tostring(vars.range[i][2])
     end
   end
   local restable={}
   local conn= env:connect(database)
   local query="select rowid,seat,meal from orders where ready is not null and delivered is null and ("..seats
   	..") order by age"
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

function deliver_display(self,lastid)
  local vars= getvars(ngx.var.remote_addr)
  local open= read_deliveries(vars)
  local lastinfo={}
  if lastid then
   local conn= env:connect(database)
   local curs,err=conn:execute("select seat,meal from orders where rowid="..tostring(lastid))
   if not curs then sqlerror=err
   else
     lastinfo=curs:fetch({},"a")
     curs:close()
   end
   conn:close()
  end
  self.title="Lieferungen"
  return self:html(function()
	if sqlerror then text(sqlerror) end
       element("font", {size=fontsize}, function()
        element("table", {width="100%"}, function()
          td({align="center",bgcolor="yellow"},function()
                a({href=self:url_for("seatpage")},"Bestellen")
            end)
          td({align="center"},function()
          	a({href=self:url_for("deliver")}, tostring(#open).." Lieferungen")
            end)
          td({align="center",bgcolor="red"},function()
                a({href=self:url_for("pay")},"Zahlen") 
            end)
          if lastid then
              tr(function() 
                      td({align="center"},lastinfo.seat)
                      td({align="center"},essen[lastinfo.meal])
                 end)
          end
 	  for i=1,#open do
              tr(function() 
                      td({align="center",bgcolor="yellow"},open[i].seat)
                      td({align="center",bgcolor="lightgreen"},essen[open[i].meal])
                      td({align="center",bgcolor="green"},function()
                      	a({href=self:url_for("delivered").."?rowid="..tostring(open[i].rowid)},"Erhalten")
                      end)
                 end)
          end
         end)
        end)
  	self.options.content_type="text/html; charset=utf-8"
  end)
end

app:get("deliver", "/deliver", deliver_display)

function read_payments(vars)
   local seats = "seat between "..tostring(vars.range[1][1]).." and "..tostring(vars.range[1][2])
   for i=2,rangesize do
     if vars.range[i][1]>0 then
       seats= seats.." or seat between "..tostring(vars.range[i][1]).." and "..tostring(vars.range[i][2])
     end
   end
   local restable={}
   local selected={}
   local conn= env:connect(database)
   local query="select seat,meal from orders where delivered is not null and paid is null and ("..seats
   	..") order by seat"
   local res,err= conn:execute(query)
   if not res then sqlerror=err 
   else
     local res2=res:fetch({},"a")
     while res2 do
       restable[res2.seat]= (restable[res2.seat] or 0.0)+ preis[res2.meal]
       res2=res:fetch({},"a")
     end
     res:close()
   end
   local selsum=0
   query="select distinct seat from payselection join orders on payselection.row=orders.rowid where ip='"..ngx.var.remote_addr.."'"
   res,err= conn:execute(query)
   if not res then sqlerror=err
   else
     local res2=res:fetch({},"n")
     while res2 do
       if restable[res2[1]] then
         selected[res2[1]]= true
         selsum= selsum+restable[res2[1]]
       end
       res2=res:fetch({},"n")
     end
     res:close()
   end      
   conn:close()
   local restable2={}
   for i,v in pairs(restable) do
     restable2[#restable2+1] = { seat=i, sum=v, selected=selected[i] }
   end
   return restable2,selsum
end

function pay_display(self)
  local vars= getvars(ngx.var.remote_addr)
  local topay,selsum= read_payments(vars)
  self.title="Bezahlen"
  return self:html(function()
	if sqlerror then text(sqlerror) end
       element("font", {size=fontsize_pay}, function()
        element("table", {width="100%"}, function()
          td({align="center",bgcolor="yellow"},function()
                a({href=self:url_for("seatpage")},"Bestellen")
            end)
          td({align="center"},function()
                a({href=self:url_for("deliver")},"Liefern")
            end)
          td({align="center",bgcolor="red"},function()
                a({href=self:url_for("paidconfirm")},string.format("%.2f€ erhalten",selsum))
            end)
 	  for i=1,#topay,3 do
             tr(function() 
	 	for j=i,i+2 do
	 	   if j<=#topay then
	 	      local color= "orange"
	 	      if topay[j].selected then color="lightgrey" end
                      td({align="center",bgcolor=color},function()
                        local content=""
                        if topay[j].selected then content=string.format("%d raus (-%.2f€)", topay[j].seat, topay[j].sum)
                        else content= string.format("%d dazu (+%.2f€)", topay[j].seat, topay[j].sum)
                        end
                      	a({href=self:url_for("paid").."?seat="..tostring(topay[j].seat)},content)
                      end)
                   end
                end
             end)
          end
         end)
        end)
  	self.options.content_type="text/html; charset=utf-8"
  end)
end

app:get("pay", "/pay", pay_display)

app:get("paid", "/paid", function(self)
  local seat = tonumber(self.params.seat)
  local conn= env:connect(database)
  local query="select count(row) from payselection join orders on payselection.row=orders.rowid where ip='"..ngx.var.remote_addr.."' and seat="..tostring(seat)
  local res,err= conn:execute(query)
  if not res then sqlerror=err
  else
    local res2=res:fetch({},"n")
    res:close()
--sqlerror="Paid res "..res2[1]
    if res2[1]>0 then
      query= "delete from payselection where ip='"..ngx.var.remote_addr.."' and exists(select 1 from orders where seat="..tostring(seat).." and orders.rowid=payselection.row)"
      local res,err= conn:execute(query)
--sqlerror=sqlerror.." "..query
      if not res then sqlerror=err end
    else
      query= "insert into payselection select '"..ngx.var.remote_addr.."',rowid from orders where seat="..tostring(seat).." and paid is null and delivered is not null"
      local res,err= conn:execute(query)
--sqlerror=sqlerror.." "..query
      if not res then sqlerror=err end
    end
    res:close()
  end      
  conn:close()
  return pay_display(self)
end)

app:get("paidconfirm", "/paidconfirm", function(self)
  local conn= env:connect(database)
  local now= os.time()
  local query="update orders set paid="..tostring(now).." where exists (select 1 from payselection where ip='"..ngx.var.remote_addr.."' and payselection.row=orders.rowid)"
  local res,err= conn:execute(query)
  if not res then sqlerror=query..": "..err end
  query="delete from payselection where ip='"..ngx.var.remote_addr.."'"
  res,err= conn:execute(query)
  if not res then sqlerror=query..": "..err end
  query="insert into completed select * from orders where paid is not null"
  res,err= conn:execute(query)
  if not res then sqlerror=query..": "..err end
  query="delete from orders where paid is not null"
  res,err= conn:execute(query)
  if not res then sqlerror=query..": "..err end
  conn:close()
  return pay_display(self)
end)

app:get("delivered", "/delivered", function(self)
  local rowid = tonumber(self.params.rowid)
  local conn= env:connect(database)
  local now= os.time()
  local query="update orders set delivered="..tostring(now).." where rowid="..tostring(rowid)
  local res,err= conn:execute(query)
  if not res then sqlerror=err end
  conn:close()
  return deliver_display(self,rowid)
end)

function kitchen_display(self,lastname,lastmeal)
  local orders,amount= read_orders()
  local now= os.time()
  self.title="Bestellungen"
  return self:html(function()
	if sqlerror then text(sqlerror) end
--       element("font", {size=fontsize}, function()
        element("table", {width="100%"}, function()
          if lastname then
            tr(function()
            	td("Fertig")
            	td({align="center"},lastname)
                td({align="center"},essen[lastmeal])
            end)
          end
 	  for i=1,#orders do
              tr(function() 
                      td(format_number(now-orders[i].age))
                      td({align="center",bgcolor="yellow"},orders[i].name)
                      td({align="center",bgcolor="lightgreen"},essen[orders[i].meal].." (von insges. "..tostring(amount[orders[i].meal])..")")
                      td({align="center",bgcolor="green"},function()
                      	a({href=self:url_for("confirm").."?rowid="..tostring(orders[i].rowid)},"Fertig")
                      end)
                 end)
          end
         end)
--        end)
        local param=""
        if lastname then
          param= "?lastmeal="..lastmeal.."&lastname="..encoding.encode_base64(lastname)
        end
  	self.res:add_header("refresh","5; URL="..self:url_for("kitchen")..param)
  	self.options.content_type="text/html; charset=utf-8"
--        self.res:add_header("viewport", "width=device-width, maximum-scale=1.0, user-scalable=yes")
  end)
end

app:get("confirm", "/confirm", function(self)
  local rowid = tonumber(self.params.rowid)
  local conn= env:connect(database)
  local now= os.time()
  local query="update orders set ready="..tostring(now).." where rowid="..tostring(rowid)
  local res,err= conn:execute(query)
  if not res then sqlerror=err end
  local query="select name,meal from orders where rowid="..tostring(rowid)
  local res,err= conn:execute(query)
  local name,meal
  if not res then sqlerror=err
  else
    name,meal = res:fetch()
    res:close()
  end
  conn:close()
  return kitchen_display(self,name,meal)
end)

app:get("cancel", "/cancel", function(self)
  local rowid = tonumber(self.params.rowid)
  local conn= env:connect(database)
  local now= os.time()
  local query="delete from orders where rowid="..tostring(rowid)
  local res,err= conn:execute(query)
  if not res then sqlerror=err end
  conn:close()
  local vars= getvars(ngx.var.remote_addr)
  return self:html(selectmeal_widget(self,vars))
end)

function read_orders()
   local restable={}
   local amount={}
   local conn= env:connect(database)
   local query="select rowid,age,name,meal from orders where ready is null order by age"
   local res,err= conn:execute(query)
   if not res then sqlerror=err 
   else
     local res2=res:fetch({},"a")
     while res2 do
       restable[#restable+1]=res2
       amount[res2.meal] = (amount[res2.meal] or 0)+1
       res2=res:fetch({},"a")
     end
     res:close()
   end
   conn:close()
   return restable,amount
end

function format_number(x)
  local hours=math.floor(x/3600)
  x=x-hours*3600
  local min=math.floor(x/60)
  x=x-min*60
  return string.format("%d:%02d:%02d", hours, min, x)
end

app:get("kitchen", "/kitchen", function(self)
  local name
  if self.params.lastname then
    name= encoding.decode_base64(self.params.lastname)
  end
  return kitchen_display(self, name, tonumber(self.params.lastmeal))
end)

return app
