function launcher(clsid, name, displayName,params, elements)
    local res		= params
	res.Weight 		= tonumber(res.Weight)
    res.CLSID 		= clsid;
    res.displayName = displayName
    res.Elements 	= elements;
	res.WorldID 	= tonumber(params.WorldID)
    return res;
end


function req_launcher(clsid, name)
    return clsid
end

function element(shape, x, y, z, ...)

	local t = {	ShapeName = shape,
			    Position  = {x,y,z},}
	for i, v in ipairs{...} do
		if t.DrawArgs == nil then
		   t.DrawArgs = {}
	   end
	   t.DrawArgs[i] = v;
	end
	return 	t
end

function drawarg(key, value)
    return {key,value};    
end

db.Weapons =
{
	Categories = {};
};

-----------------------------------------------
dofile ("scripts/Database/db_weapons_data.lua")
-----------------------------------------------
db.Weapons.ByCLSID = {}

function get_weapon_display_name_by_clsid(clsid)
	local  lnchr = db.Weapons.ByCLSID[clsid] 
	if lnchr then 
	   return lnchr.displayName or clsid 
	end
	return clsid 
end


local weapons_names = nil

function create_names()

	weapons_names = 
	{
		types = {},
		sht   = {},
	}
	for i,lnchr in pairs(db.Weapons.ByCLSID) do
	   local ws_type  = lnchr.attribute
	   local str_form = wsTypeToString(ws_type)
	   if ws_type then
		   if  lnchr.kind_of_shipping == 2 then 
			    weapons_names.types[str_form]	= lnchr.displayName
		   elseif ws_type[1]  == wsType_Weapon and 
					 ws_type[3]  ~= wsType_Container and   
					 (lnchr.Count == nil or lnchr.Count == 1)then
				weapons_names.types[str_form]	= lnchr.displayName
		   elseif 	ws_type[1] == wsType_Air and
					ws_type[2] == wsType_Free_Fall then
				weapons_names.types[str_form]	= lnchr.displayName
		   end	   
	   end
	end
	local desc_tables = {weapons_table.weapons.bombs,
						 weapons_table.weapons.missiles,
						 weapons_table.weapons.nurs,
						 weapons_table.weapons.torpedoes,
						 }					 
	for i,tbl in ipairs(desc_tables) do
		for nm,desc in pairs(tbl) do	
			if desc.ws_type ~= nil then
				--print(nm)
				local ws_type  = {wsType_Weapon,desc.ws_type[1],desc.ws_type[2],desc.ws_type[3]}
				local dsp_name = desc.display_name or desc.name or nm
				local str_form = wsTypeToString(ws_type)
				
				if weapons_names.types[str_form] == nil then
				   weapons_names.types[str_form] = dsp_name			
				end
			end
		end
	end

	local f       = {}
	local err     = {} 
	
	f[1],err[1] = loadfile("Bazar/BombTable.sht")
	f[2],err[2] = loadfile("Bazar/MissileTable.sht")
	f[3],err[3] = loadfile("Bazar/ContainerTable.sht")
	
	local tmp_env = {}
	for i,file in ipairs(f) do
		if file then
			setfenv(file,tmp_env)  
			file()
		else 
			print(err[i]);
		end		
	end
	
	for key,sht_tbl in pairs(tmp_env) do
		weapons_names.sht[key] = {}
		local i = 1
		while sht_tbl[i] do
			local ind = sht_tbl[i].index
			local str = sht_tbl[i].username
			if str and ind then
			   weapons_names.sht[key][ind] = str
			end
			i = i + 1
		end
	end
	if ModsWeaponNames then 
		for i,o in pairs(ModsWeaponNames) do
			weapons_names.types[i] = o
		end	
	end
end

function get_weapon_display_name_by_wstype(ws_type)
	
	if not weapons_names then
	   create_names()
	end	
	
	local str_form     = wsTypeToString(ws_type)
	local ws_type_name = weapons_names.types[str_form]
	
	if ws_type_name then
		return ws_type_name
	end

	if 	   ws_type[1] == wsType_Air then
		if ws_type[2] == wsType_Free_Fall then
		   return weapons_names.sht.ContainerTable[ws_type[4]] or ""
		end
	elseif 		ws_type[1] == wsType_Weapon then
		if		ws_type[2] == wsType_Missile 	or
				ws_type[2] == wsType_NURS 		then 
				return weapons_names.sht.MissileTable[ws_type[4]]  or ""
		elseif	ws_type[2] == wsType_Bomb 		then
				return weapons_names.sht.BombTable[ws_type[4]]  or ""
		elseif  ws_type[2] == wsType_GContainer then
				return weapons_names.sht.ContainerTable[ws_type[4]]  or ""
		end
	end
	return ""
end

function get_weapon_and_count_from_launcher(clsid)
	local launcher = db.Weapons.ByCLSID[clsid]
	if launcher == nil then
		return {0,0,0,0},0
	end
	local count = 1
	if launcher.Count ~= nil then
	   count = launcher.Count
	end
	local weapon = launcher.wsTypeOfWeapon or 
				   launcher.attribute or 
				   {0,0,0,0}
	return weapon,count
end

function collect_available_weapon_resources_wstype()
	local wstypes = {}
	
	local collect = function (wstype)
		if wstype ~= nil then
			local str_form = wsTypeToString(wstype)
			if wstypes[str_form] == nil then
			   if str_form ~= '' and  str_form ~= '0.0.0.0'  then
				  wstypes[str_form] = wstype
			   end
			end
		end
	end
	
	
	for i,launcher in pairs(db.Weapons.ByCLSID) do
		if launcher.kind_of_shipping == 2 then --SOLID_MUNITION
		   collect(launcher.attribute)
		elseif launcher.kind_of_shipping == 1 then --SUBMUNITION_AND_CONTAINER_SEPARATELY
		   if  launcher.adapter_type then
				collect(launcher.adapter_type)
		   else
				collect(launcher.attribute)
		   end
		   collect(launcher.wsTypeOfWeapon)
		else
		   collect(launcher.wsTypeOfWeapon or launcher.attribute) 
		end
	end
	
	return wstypes
end

function collect_available_weapon_resources()	
	local res = {}
	local insert = table.insert
	
	for str_form, wstype in pairs(collect_available_weapon_resources_wstype()) do
		insert(res, str_form)
	end
	
	table.sort(res)
	
	return res
end


-- by uboats
local base = _G

function dbg_print(s)
    base.print(s)
end
    
function get_weapon_element_by_clsid(clsid)
	local lnchr = db.Weapons.ByCLSID[clsid]
	if lnchr then
	   return lnchr.Elements or nil
	end
	return nil
end

function get_weapon_launcher_by_clsid(clsid)
	local lnchr = db.Weapons.ByCLSID[clsid]

	if lnchr and lnchr.Elements then
        lnchr.Elements_new = lnchr.Elements        
        return lnchr
	end
    
	return nil
end
-- by uboats
