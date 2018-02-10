local lapis = require("lapis")
local app = lapis.Application()
local encoding = require("lapis.util.encoding")

local DBI = require('DBI')

local sqlerror

local columns=3
local maxseat=333
local database="/var/local/meals/meals.db"
local rangesize=4
local max
local fontsize=8
local fontsize_meals=fontsize-1
local fontsize_seats=fontsize+1
local fontsize_pay=fontsize+1
local imgsize=50
local useimage=false --true
local kitchencolumns=3

local lightgreen= "lightgreen"
local lime= "lime"
local lawngreen= "lawngreen"
local greenyellow= "GreenYellow"

local goods={{"Fl. Rotwein", 12, "rotwein_flasche.jpg", lime },
	{"Glas Rotwein", 3, "rotwein-glas.jpg", lightgreen },
	{"Fl. Weißwein", 12, "weisswein_flasche.jpg", lime },
	{"Glas Weißwein", 3, "weissglas.jpg", lightgreen },
	--{"Fl. Sekt", 8.5, "sektfl.jpg", lightgreen },
	{"Glas Sekt", 3, "sektglas.jpeg", lightgreen },
	{"Pils", 2.5, "pils.jpg", lime },
	{"Kölsch", 2.5, "koelsch.jpg", lime },
	{"Alt", 2.5, "altbier.jpg", lime },
	{"alkfrei", 2.5, "alkoholfrei.jpg", lime },
	--"Korn", "Weinbrand",
	{"Tequila", 1.5, "Tequila.jpg",lightgreen },
	{"Vodka", 1.5, "Vodka.png",lightgreen },
	{"Klopfer", 1.5, "Klopfer.png",lightgreen },
	{"Shot", 1.5, "Shot.png",lightgreen },
	{"Fl. Wasser", 4.5, "FWasser.png",lime },
	{"Glas Wasser", 1, "GWasser.png",lightgreen },
	{"Cola", 1, "cola.png" ,lightgreen},
	{"Fanta", 1, "Fanta.png",lightgreen },
	{"Sprite", 1, "Sprite.png",lightgreen }, 
	--"O-Saft","A-Saft", 
	{"Tee", 1, "Tee.png",lightgreen }, 
	{"Kaffee", 1.5, "Kaffee.png",lightgreen },
	{"Cocktail", 5, "Cocktail.png",lightgreen },

	{"Wurst+Brot", 3, "WurstBrot.png",lawngreen },
	{"Wurst+Kart.", 4.5, "WurstKart.png",lawngreen},
	{"Schnitzel+Brot", 4, "SchnitzelBrot.png",lawngreen},
	{"Schnitzel+Kart.", 5.5, "SchnitzelKart.png",lawngreen},
	{"Frikad.+Brot", 3.5, "FrikadBrot.png",lawngreen },
	{"Frikad.+Kart.", 5, "FrikadKart.png",lawngreen},
	{"Bratling+Brot", 3.5, "BratlKart.png",lawngreen},
	{"Bratling+Kart.", 5, "BratlKart.png",lawngreen},
	{"Gulaschsuppe", 3, "Gulaschs.png",lawngreen},
	{"Rote Grütze", 2.5, "RoteGrue.png",greenyellow},
	{"Chips", 1, "Chips.png",greenyellow},
	{"Salzstangen", 1, "Salzstangen.png",greenyellow},
	--{"Brezel",1, "Brezel.png",greenyellow},
}
local essen={}
local preis={}
local image={}
local color={}

for i,j in ipairs(goods) do
	essen[i]=j[1]
	preis[i]=j[2]
	image[i]=j[3]
	color[i]=j[4]
end
	
--local color = { "lightgreen", "lime", "lawngreen", "GreenYellow" }

local function getvars(ip)
   local conn= assert(DBI.Connect("SQLite3", database))
   local stmt,err= conn:prepare("select name,from1,to1,from2,to2,from3,to3,from4,to4,seat,mealpage,rows "
   	.."from users where ip=?")
   if not stmt then 
   	sqlerror=err
   	return 
   end  
   stmt:execute(ip)
   local res= stmt:fetch(true)
   local x={}
   if not res then
     x= {name=ip, range={{0,0},{0,0},{0,0},{0,0}}, seat=1, mealpage=1, rows=3 }
     local query="insert into users (name,from1,to1,from2,to2,from3,to3,from4,to4,seat,ip,mealpage,rows) "
     	.."values (?,0,0,0,0,0,0,0,0,1,?,1,3)"
     local res,err= DBI.Do(conn, query, ip, ip)
     if not res then sqlerror=err end
     conn:commit()
   else
     x= {name=res.name, range={{res.from1,res.to1},{res.from2,res.to2},{res.from3,res.to3},{res.from4,res.to4}}, 
     	seat=res.seat, mealpage=res.mealpage, rows=res.rows}
   end
   stmt:close()
   conn:close()
   return x
end

local function setvars(ip,vars)
   local conn= assert(DBI.Connect("SQLite3", database))
   local res,err= DBI.Do(conn, "update users set name=?, from1=?,to1=?,from2=?,to2=?,"
   	.."from3=?,to3=?, from4=?,to4=?, seat=?,rows=?,mealpage=? "
   	.."where ip=?",
   		vars.name, 
   		vars.range[1][1], vars.range[1][2],
   		vars.range[2][1], vars.range[2][2],
   		vars.range[3][1], vars.range[3][2],
   		vars.range[4][1], vars.range[4][2],
   		vars.seat, vars.rows, vars.mealpage, ip)
   if not res then sqlerror=err 
   else conn:commit()
   end
   conn:close()
end

local function seat_clause(vars)
   local args={ vars.range[1][1],vars.range[1][2] }
   local seats = "seat between ? and ?"
   for i=2,rangesize do
     if vars.range[i][1]>0 then
       seats= seats.." or seat between ? and ?"
       table.insert(args, vars.range[i][1])
       table.insert(args, vars.range[i][2])
     end
   end
   return seats,args
end

local function execute_varargs(res,args)
     if not args[3] then res:execute(args[1],args[2])
     elseif not args[5] then res:execute(args[1],args[2],args[3],args[4])
     elseif not args[7] then res:execute(args[1],args[2],args[3],args[4],args[5],args[6])
     else res:execute(args[1],args[2],args[3],args[4],args[5],args[6],args[7],args[8])
     end
end

local function has_deliveries(vars)
   local seats,args = seat_clause(vars)
   local count=false
   local conn= assert(DBI.Connect("SQLite3", database))
   local query="select 1 from orders where ready is not null and delivered is null and ("..seats..") limit 1"
   local res,err= conn:prepare(query)
   if not res then sqlerror=err 
   else
     execute_varargs(res,args)
     if res:fetch(false) then count=true end
--     print("has deliveries ",count," ")
     res:close()
   end
   conn:close()
   return count
end

local function has_payments(vars)
   local seats,args = seat_clause(vars)
   local count=false
   local conn= assert(DBI.Connect("SQLite3", database))
   local query="select 1 from orders where delivered is not null and paid is null and ("..seats..") limit 1"
   local res,err= conn:prepare(query)
   if not res then sqlerror=err 
   else
     execute_varargs(res,args)
     if res:fetch(false) then count=true end
     res:close()
   end
   conn:close()
   return count
end

local function highlight(text,yes)
--   print("highlight ",text," ",yes)
   if yes then return "->"..text.."<-" end
   return text
end

local function loginscreen(self)
  self.title="Login"
  return self:html(function()
    local vars= getvars(ngx.var.remote_addr)
   element("font", {size=fontsize+4}, function()
    form({action=self:url_for("login")}, function()
        text("Name")
    	input{type="text", name="name", value=vars.name}
    	br()
    	text("Tischnummern")
    	br()
    	for i=1,rangesize do
          input{type="number", size="3", maxlength="3", name="from"..tostring(i), value=tostring(vars.range[i][1]), min=0, max=maxseat}
          text("-")
          input{type="number", size="3", maxlength="3", name="to"..tostring(i), value=tostring(vars.range[i][2]), min=0, max=maxseat}
          br()
    	end
    	text("Zeilen ")
    	input{type="number", name="rows", value=vars.rows, min=3, max=20 }
    	br()
    	input{type="submit", value="Start"}
      end)
    end)
--      self.res:add_header("HandheldFriendly", "true")
  end)
end

app:get("/", loginscreen)

app:get("/start", loginscreen)

local function table_print (tt,depth)
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

local function create_seatlist(vars)
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

local function selectseat_widget(self,vars)
    local list= create_seatlist(vars)
    local deliveries=has_deliveries(vars)
    local payments=has_payments(vars)
    local seatcols= 2*columns
    local elems_page= seatcols*vars.rows-1
    -- complete to 9 elements
    local missing= elems_page-#list
    --print(" list ",#list," missing ",missing)
    for i=1,missing do 
      list[#list+1]=list[i]
    end
    local posinlist=1
    --print(" #list ",#list," seat ",vars.seat)
    for i=1,#list do
      if vars.seat>=list[i] then 
        posinlist=i
      end
    end
    local pagestart=math.floor((posinlist-1)/(elems_page))*(elems_page)
    --print(" posinlist ",posinlist," pagestart ",pagestart)
    -- pagestart starts at 0
    if pagestart+elems_page>#list then pagestart=#list-(elems_page) end
    --print(" pagestart ",pagestart," elems_page ",elems_page," ")
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
                  	a({href=self:url_for("deliver")},highlight("Liefern",deliveries))
                    end)
                  td({align="center",colspan="2",bgcolor="red"},function()
                  	a({href=self:url_for("pay")},highlight("Zahlen",payments)) 
                    end)
          end)
          for i=1,vars.rows-1 do
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
                  	a({href=self:url_for("seat").."?seat="..tostring(list[pagestart+vars.rows*seatcols-seatcols+j])},tostring(list[pagestart+vars.rows*seatcols-seatcols+j]))
                     end)
                end
                td({align="center"},function()
       			local newstart=pagestart+seatcols*vars.rows
       			--newstart starts at 1
       			--print(" pagestart ",pagestart," newstart ",newstart)
       			if newstart>#list then newstart=1
--       			elseif newstart+elems_page>#list then newstart=#list-(elems_page)+1
       			end
--text("NS "..newstart.." "..elems_page.." "..#list)
                  	a({href=self:url_for("seatpage").."?start="..tostring(list[newstart])},">>")
                     end)
            end)
      end)
     end)
--      self.res:add_header("HandheldFriendly", "true")
    end
end

local function order_statistics(seat)
   local conn= assert(DBI.Connect("SQLite3", database))
   local res= os.time()
   local open=0
   local query="select meal,rowid,ready from orders where delivered is null and seat=? order by age"
   local res,err= conn:prepare(query)
   local restable={}
   if not res then sqlerror=err 
   else
     res:execute(seat)
     for res2 in res:rows(true) do
       restable[#restable+1]={ meal=res2.meal, rowid=res2.rowid, ready=res2.ready }
     end
     res:close()
   end
   conn:close()
   return restable
   --string.format("%d offene Bestellungen", open)
end

local function selectmeal_widget(self,vars)
    local deliveries=has_deliveries(vars)
    local payments=has_payments(vars)
    local elems_page = columns*vars.rows-1
    local pagestart=math.ceil((vars.mealpage-1)/(elems_page))*(elems_page)
    -- pagestart starts at 0
    if pagestart+elems_page>#essen then pagestart=#essen-(elems_page) end
    if pagestart<0 then pagestart=0 end
    local rows_displayed=vars.rows
    local next_page=1
    if rows_displayed*columns>=#essen then
      next_page=0
      rows_displayed=math.ceil(#essen/columns)
    end
    self.title="Bestellen"
    return function()
      if sqlerror then text(sqlerror) end
--      p({style="font-size: x-large;"},function()
     element("font", {size=fontsize_meals}, function()
      element("table", {width="100%"}, function()
      --'<table width="100%">'
          tr(function() 
                  td({align="center",bgcolor="yellow"},function()
                  	a({href=self:url_for("seatpage")},"Tisch "..tostring(vars.seat))
                    end)
                  td({align="center"},function()
                  	a({href=self:url_for("deliver")},highlight("Liefern",deliveries))
                    end)
                  td({align="center",bgcolor="red"},function()
                  	a({href=self:url_for("pay")},highlight("Zahlen",payments)) 
                    end)
          end)
          if useimage then
           for i=1,rows_displayed-next_page do
            tr(function() 
            	for j=1,columns do
            	  local index=pagestart+i*columns-columns+j
                  td({align="center",bgcolor=color[index]},function()
                  	a({href=self:url_for("order").."?meal="..tostring(index)},
                  	function()
                  		img({src="/static/"..image[index],
                  		alt=essen[index],width=imgsize,height=imgsize})
                  	end)
                  end)
                end
            end)
           end
          else
           for i=1,rows_displayed-next_page do
            tr(function() 
            	for j=1,columns do
            	  local index=pagestart+i*columns-columns+j
                  td({align="center",bgcolor=color[index]},function()
                  	a({href=self:url_for("order").."?meal="..tostring(index)},
                  		essen[index])
                  end)
                end
            end)
           end
          end
          if next_page>0 then
           tr(function() 
              for j=1,columns-1 do
                local index=pagestart+vars.rows*columns-columns+j
                td({align="center",bgcolor=color[index]},function()
                      a({href=self:url_for("order").."?meal="..tostring(index)},
                      		essen[index])
                end)
              end
              td({align="center"},function()
                      local newstart=pagestart+columns*vars.rows
                      --newstart starts at 1
                      if newstart>#essen then newstart=1
                      elseif newstart+elems_page>#essen then newstart=#essen-(elems_page)+1
                      end
                      a({href=self:url_for("mealpage").."?start="..tostring(newstart)}," >> ")
                   end)
           end)
          end
          local stats= order_statistics(vars.seat)
          if #stats>0 then
              tr(function()
                td("Bestellt:")
              end)
          end
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

local function canonicalize(t)
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
    vars.range[i][1]= tonumber(self.params["from"..tostring(i)] or "0") or 0
    vars.range[i][2]= tonumber(self.params["to"..tostring(i)] or "0") or 0
  end
  vars.rows= self.params.rows or vars.rows
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

local function store_order(name,seat,meal)
   local conn= assert(DBI.Connect("SQLite3", database))
   local now= os.time()
   local query="insert into orders (age,name,seat,meal) values (?,?,?,?)"
   local res,err= DBI.Do(conn, query, now, name, seat, meal)
   if not res then sqlerror=err else conn:commit() end
   conn:close()
end

app:get("order", "/order", function(self)
  local vars= getvars(ngx.var.remote_addr)
  local meal= tonumber(self.params.meal)
  store_order(vars.name,vars.seat,meal)
  return self:html(selectmeal_widget(self,vars))  
end)

local function read_deliveries(vars)
   local seats,args = seat_clause(vars)
   local restable={}
   local conn= assert(DBI.Connect("SQLite3", database))
   local query="select rowid,seat,meal from orders where ready is not null and delivered is null and ("..seats
   	..") order by age"
   local res,err= conn:prepare(query)
   if not res then sqlerror=err 
   else
     execute_varargs(res,args)
     --sqlerror= query..":"..tostring(args[1])..","..tostring(args[2])
     for res2 in res:rows(true) do
       restable[#restable+1]=res2
     end
     res:close()
   end
   conn:close()
   return restable
end

local function deliver_display(self,lastid)
  local vars= getvars(ngx.var.remote_addr)
  local payments=has_payments(vars)
  local open= read_deliveries(vars)
  local lastinfo={}
  if lastid then
   local conn= assert(DBI.Connect("SQLite3", database))
   local curs,err=conn:prepare("select seat,meal from orders where rowid=?")
   if not curs then sqlerror=err
   else
     curs:execute(lastid)
     lastinfo=curs:fetch(true)
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
                a({href=self:url_for("pay")},highlight("Zahlen",payments)) 
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

local function read_payments(vars)
   local seats,args= seat_clause(vars)
   local restable={}
   local selected={}
   local conn= assert(DBI.Connect("SQLite3", database))
   local query="select seat,meal from orders where delivered is not null and paid is null and ("..seats
   	..") order by seat"
   local res,err= conn:prepare(query)
   if not res then sqlerror=err 
   else
     execute_varargs(res,args)
     for res2 in res:rows(true) do
       restable[res2.seat]= (restable[res2.seat] or 0.0)+ preis[res2.meal]
     end
     res:close()
   end
   local selsum=0
   query="select distinct seat from payselection join orders on payselection.row=orders.rowid where ip=?"
   res,err= conn:prepare(query)
   if not res then sqlerror=err
   else
     res:execute(ngx.var.remote_addr)
     for res2 in res:rows() do
       if restable[res2[1]] then
         selected[res2[1]]= true
         selsum= selsum+restable[res2[1]]
       end
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

local function pay_display(self)
  local vars= getvars(ngx.var.remote_addr)
  local topay,selsum= read_payments(vars)
  local deliveries=has_deliveries(vars)
  self.title="Bezahlen"
  return self:html(function()
	if sqlerror then text(sqlerror) end
       element("font", {size=fontsize_pay}, function()
        element("table", {width="100%"}, function()
          td({align="center",bgcolor="yellow"},function()
                a({href=self:url_for("seatpage")},"Bestellen")
            end)
          td({align="center"},function()
                a({href=self:url_for("deliver")},highlight("Liefern",deliveries))
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
  local conn= assert(DBI.Connect("SQLite3", database))
  local query="select count(row) from payselection join orders on payselection.row=orders.rowid where ip=? and seat=?"
  local res,err= conn:prepare(query)
  if not res then sqlerror=err
  else
    res:execute(ngx.var.remote_addr, seat)
    local res2 = res:fetch()
    res:close()
--sqlerror="Paid res "..res2[1]
    if res2[1]>0 then
      query= "delete from payselection where ip=? and exists(select 1 from orders where seat=? and orders.rowid=payselection.row)"
      local res,err= DBI.Do(conn, query, ngx.var.remote_addr, seat)
--sqlerror=sqlerror.." "..query
      if not res then sqlerror=err end
    else
      query= "insert into payselection select ?,rowid from orders where seat=? and paid is null and delivered is not null"
      local res,err= DBI.Do(conn, query, ngx.var.remote_addr, seat)
--sqlerror=sqlerror.." "..query
      if not res then sqlerror=err end
    end
    conn:commit()
    res:close()
  end      
  conn:close()
  return pay_display(self)
end)

app:get("paidconfirm", "/paidconfirm", function(self)
  local conn= assert(DBI.Connect("SQLite3", database))
  local now= os.time()
  local query="update orders set paid=? where exists (select 1 from payselection where ip=? and payselection.row=orders.rowid)"
  local res,err= DBI.Do(conn,query,now,ngx.var.remote_addr)
  if not res then sqlerror=query..": "..err end
  query="delete from payselection where ip=?"
  res,err= DBI.Do(conn,query,ngx.var.remote_addr)
  if not res then sqlerror=query..": "..err end
  query="insert into completed select * from orders where paid is not null"
  res,err= DBI.Do(conn,query)
  if not res then sqlerror=query..": "..err end
  query="delete from orders where paid is not null"
  res,err= DBI.Do(conn,query)
  if not res then sqlerror=query..": "..err end
  conn:commit()
  conn:close()
  return pay_display(self)
end)

app:get("delivered", "/delivered", function(self)
  local rowid = tonumber(self.params.rowid)
  local conn= assert(DBI.Connect("SQLite3", database))
  local now= os.time()
  local query="update orders set delivered=? where rowid=?"
  --..tostring(now).." where rowid="..tostring(rowid)
  local res,err= DBI.Do(conn,query, now,rowid)
  if not res then sqlerror=err 
  else conn:commit() end
  conn:close()
  return deliver_display(self,rowid)
end)

local function format_number(x)
  local hours=math.floor(x/3600)
  x=x-hours*3600
  local min=math.floor(x/60)
  x=x-min*60
  return string.format("%d:%02d:%02d", hours, min, x)
end

local function read_orders_and_waiting(part)
   local restable={}
   local amount={}
   local waiting={}
   local conn= assert(DBI.Connect("SQLite3", database))
--   local query="select rowid,age,name,meal from orders where ready is null order by age"
   local query="select rowid,age,name,meal from orders where ready is null order by meal,name"
   local res,err
  if not part or part==1 then
   res,err= conn:prepare(query)
   if not res then sqlerror=err 
   else
     res:execute()
     for res2 in res:rows(true) do
       restable[#restable+1]=res2
       amount[res2.meal] = (amount[res2.meal] or 0)+1
     end
     res:close()
   end
  end
  if not part or part==2 then
   query="select name,meal,count(meal) from orders where ready is not null and delivered is null group by name,meal order by name"
   res,err= conn:prepare(query)
   if not res then sqlerror=err 
   else
     res:execute()
     for res2 in res:rows(true) do
       waiting[#waiting+1]= { res2.name, res2.meal, res2["count(meal)"] }
     end
     res:close()
   end
  end
   conn:close()
   return restable,amount,waiting
end

local function kitchen_display(self,lastname,lastmeal,part)
  local orders,amount,waiting= read_orders_and_waiting(part)
  local now= os.time()
  self.title="Bestellungen"
  if part==2 then self.title="Lieferungen" end
--  print("kitchen\n")
  return self:html(function()
	if sqlerror then text(sqlerror) end
--       element("font", {size=fontsize}, function()
       if not part or part~=2 then
        element("table", {width="100%"}, function()
          if lastname then
            tr(function()
            	td("Fertig")
            	td({align="center"},lastname)
                td({align="center"},function()
	                text(essen[lastmeal] .. " ")
                	a({href=self:url_for("kitchen_back")},"(Zurück)") end)
            end)
          end
 	  for i=1,#orders,kitchencolumns do
              tr(function() 
              	  for j=0,kitchencolumns-1 do
              	    local order=orders[i+j]
              	    if order then
                      td({align="right"},format_number(now-order.age))
                      td({align="center",bgcolor="yellow"},order.name)
                      td({align="left",bgcolor=color[order.meal]}, function()
                        if not part then part=0 end
                      	a({href=self:url_for("confirm").."?rowid="..tostring(order.rowid).."&part="..tostring(part)}, essen[order.meal])
                      	if amount[order.meal]>1 then
                        	text(" (insges. "..tostring(amount[order.meal])..")")
                        end
                      end)
                    end
                  end
                 end)
          end
          if #orders<1 and not lastname then
              -- just to not show an empty page
              text("Keine offenen Bestellungen")
          end
         end)
        end
        if not part or part~=1 then
         if #waiting>0 then
          if not part or part~=2 then
            br()
            text("Auslieferungen")
          end
          element("table", {width="100%"}, function()
             local last="."
             for i=1,#waiting do
              if waiting[i][1]~=last then
               last=waiting[i][1]
               tr(function()
                td(waiting[i][1])
                local what=""
                if waiting[i][3]>1 then what=tostring(waiting[i][3]).."x " end
                what = what .. essen[waiting[i][2]]
                for j=i+1,#waiting do
                  if waiting[j][1]==waiting[i][1] then
                    what=what..", "
                    if waiting[j][3]>1 then what=what..tostring(waiting[j][3]).."x " end
                    what = what .. essen[waiting[j][2]]
                  end
                end
                td(what)
               end)
              end
             end
          end)
         end
         if part==2 and #waiting==0 then
              -- just to not show an empty page
              text("Keine offenen Lieferungen")
         end
        end
--        end)
        local param=""
        if lastname then
          param= "?lastmeal="..lastmeal.."&lastname="..encoding.encode_base64(lastname)
        end
        local urlbase="kitchen"
        if part==1 then urlbase="kitchen1"
        elseif part==2 then urlbase="kitchen2"
        end
  	self.res:add_header("refresh","5; URL="..self:url_for(urlbase)..param)
  	self.options.content_type="text/html; charset=utf-8"
--        self.res:add_header("viewport", "width=device-width, maximum-scale=1.0, user-scalable=yes")
  end)
end

app:get("kitchen_back", "/kitchen_back", function(self)
  local conn= assert(DBI.Connect("SQLite3", database))
  local query="select rowid,name,meal,ready from orders order by ready desc limit 2"
  local res,err= conn:prepare(query)
  local res3={}
  if not res then sqlerror=err
  else
    res:execute()
--    local report="reported "
    for res2 in res:rows(true) do
    	res3[#res3+1]={ rowid=res2.rowid, name=res2.name, meal=res2.meal }
--    	report=report .. "selected ".. tonumber(res2.rowid).. " "
    end
--    error(report)
    query= "update orders set ready=null where rowid=?"
    res,err= DBI.Do(conn,query,res3[1].rowid)
    if not res then sqlerror=query..": "..err end
  end
  conn:commit()
  conn:close()
  return kitchen_display(self,res3[2].name,res3[2].meal,1)
end)

app:get("confirm", "/confirm", function(self)
  local rowid = tonumber(self.params.rowid)
  local part = tonumber(self.params.part)
  local conn= assert(DBI.Connect("SQLite3", database))
  local now= os.time()
  local query="update orders set ready=? where rowid=?"
  local res,err= DBI.Do(conn,query,now,rowid)
  conn:commit()
  if not res then sqlerror=err end
  local query="select name,meal from orders where rowid=?"
  local res,err= conn:prepare(query)
  local name,meal
  if not res then sqlerror=err
  else
    res:execute(rowid)
    local res2= res:fetch()
    name,meal = res2[1], res2[2]
    res:close()
  end
  conn:close()
  return kitchen_display(self,name,meal,part)
end)

app:get("cancel", "/cancel", function(self)
  local rowid = tonumber(self.params.rowid)
  local conn= assert(DBI.Connect("SQLite3", database))
  local now= os.time()
  local query="delete from orders where rowid=?"
  local res,err= DBI.Do(conn, query, rowid)
  if not res then sqlerror=err 
  else conn:commit() end
  conn:close()
  local vars= getvars(ngx.var.remote_addr)
  return self:html(selectmeal_widget(self,vars))
end)

app:get("kitchen", "/kitchen", function(self)
  local name
  if self.params.lastname then
    name= encoding.decode_base64(self.params.lastname)
  end
  return kitchen_display(self, name, tonumber(self.params.lastmeal))
end)

app:get("kitchen1", "/kitchen1", function(self)
  local name
  if self.params.lastname then
    name= encoding.decode_base64(self.params.lastname)
  end
  return kitchen_display(self, name, tonumber(self.params.lastmeal),1)
end)

app:get("kitchen2", "/kitchen2", function(self)
  local name
  if self.params.lastname then
    name= encoding.decode_base64(self.params.lastname)
  end
  return kitchen_display(self, name, tonumber(self.params.lastmeal),2)
end)

return app
