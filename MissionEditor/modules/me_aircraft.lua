local base = _G

module('me_aircraft')

local require = base.require
local pairs = base.pairs
local ipairs = base.ipairs
local print = base.print
local table = base.table
local string = base.string
local tonumber = base.tonumber
local tostring = base.tostring
local assert = base.assert
local math = base.math

-- Модули LuaGUI
local ListBoxItem				= require('ListBoxItem')
local MsgWindow					= require('MsgWindow')
local DialogLoader				= require('DialogLoader')
local CoalitionController		= require('Mission.CoalitionController')

-- Модуль сериализации таблицы
local S = 						require('Serializer')

-- Модули Black Shark
local U = 						require('me_utilities')	-- Утилиты создания типовых виджетов
local crutches = 				require('me_crutches')  -- temporary crutches
local MapWindow = 				require('me_map_window')
local i18n = 					require('i18n')
local tabs = 					require('me_tabs')
local DB = 						require('me_db_api')
local GroupVariant = 			require('GroupVariant')
local module_mission = 			require('me_mission')
local panel_route = 			require('me_route')
local panel_failures = 			require('me_failures')
local panel_payload = 			require('me_payload')
local panel_suppliers = 		require('me_suppliers')
local panel_triggered_actions = require('me_triggered_actions')
local panel_targeting = 		require('me_targeting')
local panel_summary = 			require('me_summary')
local panel_radio = 			require('me_panelRadio')
local panel_paramFM           = require('me_paramFM')
local panel_wpt_properties = 	require('me_wpt_properties')
local panel_loadout = 			require('me_loadout')
local toolbar = 				require('me_toolbar')
local panel_units_list			= require('me_units_list')
local panel_fix_points			= require('me_fix_points')
local panel_nav_target_points	= require('me_nav_target_points')
local OptionsData				= require('Options.Data')
local panel_showId				= require('me_showId')
local panel_ship                = require('me_ship')
local panel_static			    = require('me_static')
local panel_vehicle			    = require('me_vehicle')
local mod_parking               = require('me_parking')
local UC				        = require('utils_common')

local taskItemSkin
local defaultTaskItemSkin
local humanAircraftItemSkin
local playerItemSkin
local validFrequencyEditBoxSkin
local invalidFrequencyEditBoxSkin

i18n.setup(_M)


vdatas = { }

__views__ = {'helicopter', 'plane'}
__view__  = __views__[1]


	cdata = 
	{
		title = {
			[ __views__[1] ] = _('HELICOPTER GROUP'),
			[ __views__[2] ] = _('AIRPLANE GROUP'),
			},
		condition = _('CONDITION'),
		probability = _('%'),
		country = _('COUNTRY'), 
		name = _('NAME'),
		task = _('TASK'),
		nothing = _('Nothing'),
		unit = _('UNIT'), 
		unit_of = _('OF'),     
		type = _('TYPE'), 
		hidden = _('HIDDEN ON MAP'),
		uncontrolled = _('UNCONTROLLED'),
		lateActivation = _('LATE ACTIVATION'),
		pilot = _('PILOT'),
		pilotList = { _('Pilot #001'), _('Pilot #002'), _('Pilot #003'), _('Pilot #004') },
		skill = _('SKILL'),
		onboard_num = _('ONBOARD'),
		callsign = _('CALLSIGN'),
        HEADING = _('HEADING'),
		comm = _('COMM'),
		MHz = _('MHz'),
		invalidFreq = _('Invalid frequency'),
		error				= _('ERROR'),
		continue_question 	= _('Continue?'),
		ok					= _('OK'),
		cancel 				= _('CANCEL'),
		modulationName		= {
			[DB.MODULATION_AM] = _('AM'),
			[DB.MODULATION_FM] = _('FM')
		}	
	}
    
    if base.LOFAC then
        cdata.unit   = _("UNIT-LOFAC")
    end

	aiSkills 		= crutches.getSkillsNames(false)
	local defaultAiSkill = aiSkills[3]
	humanSkills 	= crutches.getSkillsNames(true)
	clientSkills 	= crutches.getSkillsNames(false, true)   --(false, true) --включение в список Client
	defaultSkill 	= crutches.getDefaultSkill()

	countries = {}

	vdatas[ __views__[1] ] = {
		name 		= _('New Helicopter Group'),
		unit 		= {number = 1, cur = 1,},
		pilots 		= { cdata.pilotList[1], }, -- имена пока что формируются автоматически
		skills 		= {}, -- формируется из Units.Skills
		onboard_num	= '050',
		callsign 	= '501',
		communication = true,
		frequency	= 127.5,
		modulation 	= 1,
		radioSet = false
		}
	vdatas[__views__[2] ] = {
		name 		= _('New Airplane Group'),
		unit 		= {number = 1, cur = 1,},
		pilots 		= { cdata.pilotList[1], }, -- имена пока что формируются автоматически
		skills 		= {}, -- формируется из Units.Skills
		onboard_num = '010',
		callsign 	= '100',
		communication = true,
		frequency	= 127.5,
		modulation 	= 1,
		radioSet = false
		}

	vdata 					= {}
	last_data				= {}
	last_data[__views__[1]] = {}
	last_data[__views__[2]] = {}
	skills					= {}
	--vdata = vdatas[__view__]

	selectionColor = {255/255, 240/255, 0/255, 1}

	curHumanControlledAircrafts = {} --список типов летательных аппаратов доступных для выбора в текушей панели
	
	local default_tasks = {} --задачи по умолчанию для каждого типа ЛА
	
-------------------------------------------------------------------------------
-- Создание и размещение виджетов
function create(x, y, w, h)
	window = DialogLoader.spawnDialogFromFile('MissionEditor/modules/dialogs/me_aircraft_group.dlg', cdata)
	window:setBounds(x, y, w, h)

	local panelSkins = window.panelSkins
	
	taskItemSkin = window.c_task:getSkin().skinData.skins.listBox.skinData.skins.item
	defaultTaskItemSkin = panelSkins.listBoxItemDefaultTask:getSkin()
	humanAircraftItemSkin = panelSkins.listBoxItemHumanAircraft:getSkin()
	playerItemSkin = panelSkins.listBoxItemPlayerAircraft:getSkin()
	validFrequencyEditBoxSkin = window.e_frequency:getSkin()
	invalidFrequencyEditBoxSkin = panelSkins.editBoxInvalidFrequency:getSkin()	
	
	countries = CoalitionController.getActiveCountries()

    -- Формирование данных по всем странам и задачам.
	createCountryTasksTable()

	setData(vdatas[__view__])

	vdata.country 	= countries[1]
	vdata.task 		= country_tasks[__view__][vdata.country][1]
	vdata.type 		= country_task_aircraft_list[__view__][vdata.country][vdata.task][1]
    
	createControls()
	updateAutoTask()

	local cx, cy, cw, ch = window:getClientRect()
  
	_tabs = tabs.createUnitTabs('aircraft', window, 0, ch - U.widget_h - 9)
	
	humanControlledAircrafts = DB.getHumanControlledAircrafts()

	clientControlledAircrafts = DB.getClientControlledAircrafts()
        
end

-------------------------------------------------------------------------------
-- Создание контролов панели
function createControls()
	-- Заголовок
	window:setText(cdata.title[__view__])
    
    btnShowId = DialogLoader.findWidgetByName(window, "btnShowId")
    
	function window:onClose()
		onButtonClose()
	end

    t_heading = window.t_heading
    sp_heading = window.sp_heading
    d_heading = window.d_heading
    
    t_heading:setVisible(false)
    sp_heading:setVisible(false)
    d_heading:setVisible(false)
    
    function sp_heading:onChange()
      local n = self:getValue()
      
      vdata.group.units[vdata.unit.cur].heading = U.toRadians(n)
      vdata.lastHeading = U.toRadians(n)
      d_heading:setValue(n)
      updateHeading()
    end

    function d_heading:onChange()
      vdata.group.units[vdata.unit.cur].heading = U.toRadians(self:getValue())
      vdata.lastHeading = U.toRadians(self:getValue())
      sp_heading:setValue(base.math.floor(self:getValue()))
      updateHeading()
    end
    
	-- комбобокс со странами
	c_country = window.c_country
	U.fill_combo(c_country, countries)
	vdata.country = countries[1]
	
	-- поле редактирования Имени
	e_name = window.e_name

	--комбобокс Задач
	c_task = window.c_task
		   
	-- Spin текущего юнита
	sp_unit = window.sp_unit
	sp_unit:setRange(1, vdata.unit.number)
	sp_unit:setValue(vdata.unit.cur)

	-- Spin общего количества юнитов
	maxUnitCount = 4

	sp_of = window.sp_of
	sp_of:setRange(1, maxUnitCount)
	sp_of:setValue(vdata.unit.number)	  

	-- комбобокс Типов 
	c_type = window.c_type
	local types = country_task_aircraft_list[__view__][vdata.country][vdata.task]

	U.fill_combo(c_type, types)
	vdata.type = types[1]
	  
	-- поле редактирования Пилота
	e_pilot = window.e_pilot

	-- комбобокс Скилов
	c_skill = window.c_skill
	U.fill_combo(c_skill, humanSkills)
	c_skill:setText(defaultAiSkill)

	-- Поле редактирования бортового номера
	e_onboard_num = window.e_onboard_num

	-- надпись Callsign
	t_callsign = window.t_callsign

	-- поле редактирования позывного
	e_callsign = window.e_callsign
	c_callsign = window.c_callsign
	e_callsignGroupNum = window.e_callsignGroupNum
	e_callsignUnitNum = window.e_callsignUnitNum

	--чекбокс Comm
	commCheckBox = window.commCheckBox

	--поле редактирования частоты
	e_frequency = window.e_frequency
	e_frequency:setText(vdata.frequency)

	--modulation label
	t_modulation = window.t_modulation

	-- чекбокс "Скрыт на карте"
	hiddenCheckbox = window.hiddenCheckbox

	-- чекбокс "Неуправляем"
	uncontrolledCheckBox = window.uncontrolledCheckBox

	-- чекбокс "Поздняя активация"
	lateActivationCheckBox = window.lateActivationCheckBox

	-- условие появления 
	e_group_condition = window.e_group_condition

	-- вероятность появления 
	sp_probability = window.sp_probability

	groupVariant = GroupVariant.new(window)

	bindControls()
end


-------------------------------------------------------------------------------
--назначаем обработчики контролам
function bindControls()
	c_country.onChange 				= onComboCountry
	e_name.onChange 				= onEditName
	c_task.onChange 				= onComboTask
	sp_unit.onChange 				= onSpinUnit
	sp_of.onChange 					= onSpinUnitOf
	c_type.onChange 				= onComboType
	e_pilot.onChange 				= onEditPilot
	c_skill.onChange 				= onComboSkill
	e_onboard_num.onChange 			= onEditOnboardNumber
	e_callsign.onChange 			= onEditCallsign
	c_callsign.onChange 			= onComboCallsign
	e_callsignGroupNum.onChange 	= onComboGroupNumCallsign
	e_frequency.onChange 			= onEditFrequency
	commCheckBox.onChange 			= onCheckComm
	hiddenCheckbox.onChange 		= MapWindow.OnHiddenCheckboxChange
	uncontrolledCheckBox.onChange	= onUncontrolled
	lateActivationCheckBox.onChange = onLateActivation
	e_group_condition.onChange		= onCondition
	sp_probability.onChange			= onProbability
    btnShowId.onChange              = onChange_ShowId
end


function onChange_ShowId()
    panel_showId.setGroup(vdata.group)
    panel_showId.show(true)
end
    
-------------------------------------------------------------------------------
--частота по умолчанию для разных типов ЛА

function getDefaultRadioFor(group)
	local firstUnit = group.units[1]
	local unitTypeDesc = DB.unit_by_type[firstUnit.type]
	local player = firstUnit.skill == crutches.getPlayerSkill() or firstUnit.skill == crutches.getClientSkill()
	return DB.getDefaultRadioFor(unitTypeDesc, player)
end

local function getDefaultRadio()
	if group ~= nil then
		return getDefaultRadioFor(vdata.group)
	else	
		local unitTypeDesc = DB.unit_by_type[vdata.type]
		local firstUnitSkill = vdata.skills[1]	
		local player = firstUnitSkill == crutches.getPlayerSkill() or firstUnitSkill == crutches.getClientSkill()
		return DB.getDefaultRadioFor(unitTypeDesc, player)
	end
end

-------------------------------------------------------------------------------
--словесные позывные для разных типов ЛА
local function getCallnames(a_id, a_type)
        return DB.db.getCallnames(a_id, a_type) or	
				DB.db.getUnitCallnames(a_id, DB.unit_by_type[a_type].attribute)
end

-------------------------------------------------------------------------------
--проверка соответствия позывных
function verifyCallnames(callname)
    local callnames
    if (vdata.group ~= nil) then
        callnames = getCallnames(vdata.group.boss.id, vdata.type)    
        for k, v in pairs(callnames) do
            if callname == v.Name then
                return true
            end
        end
    end
	return false
end

-------------------------------------------------------------------------------
--получение нового бортового номера
function getNewOnboard_num(a_unit)
	local maxOnboard_num = 0
	local curNumFlag = false
	local group = a_unit.boss
	local country = group.boss
	for _tmp1, type in ipairs({'plane', 'helicopter'}) do
		for _tmp2, group in ipairs(country[type].group) do
			for _tmp3, unit in ipairs(group.units) do
				if (maxOnboard_num < (tonumber(unit.onboard_num) or 0)) then
					maxOnboard_num = tonumber(unit.onboard_num)
				end
				if (vdata.onboard_num == unit.onboard_num) then
					curNumFlag = true
				end
			end
		end
	end


	if (curNumFlag == true) then
		maxOnboard_num = maxOnboard_num + 1
		return string.format("%03d",maxOnboard_num)
	end

	return vdata.onboard_num
end

-------------------------------------------------------------------------------
-- Изменение позывного
function changeCallsign()
    local callsign, onboardNum = '', ''
    local countryName = c_country:getText() --vdata.group.boss
    local westernCountry = U.isWesternCountry(countryName)
    if vdata.group then
        callsign = vdata.group.units[vdata.unit.cur].callsign
        if westernCountry then -- новая страна западная
            if not isWesternCallsign(callsign) then -- старый позывной не западный, надо поменять на западный
                for i, unit in ipairs(vdata.group.units) do
                    local callsignName, groupId, unitId
                    callsign, callsignName, groupId, unitId = getNewCallsign(unit)
                    print('changing callsign from ' .. unit.callsign .. ' to ' .. callsign, vdata.unit.cur)
                    unit.callsign = callsign
                    if unit == vdata.group.units[vdata.unit.cur] then
                        c_callsign:setText(callsignName)
						e_callsignGroupNum:setText(groupId)
						e_callsignUnitNum:setText(unitId)
                    end
                end
			else
				local str = string.match(callsign, '%D+') or callsign
				if (verifyCallnames(str) == false) then
					callsign = getNewCallsign(vdata.group.units[1])
					str = string.match(callsign, '%D+') or callsign
							
					for i, unit in ipairs(vdata.group.units) do
						local callsignName, groupId, unitId
						callsign, callsignName, groupId, unitId = getNewCallsign(unit)
						unit.callsign = callsign
						if unit == vdata.group.units[vdata.unit.cur] then
							c_callsign:setText(callsignName)
							e_callsignGroupNum:setText(groupId)
							e_callsignUnitNum:setText(unitId)
						end
					end
				end
            end
        else -- новая страна восточная
            for i, unit in ipairs(vdata.group.units) do
                local callsignName, groupId, unitId
                callsign, callsignName, groupId, unitId = getNewCallsign(unit)
                unit.callsign = callsign
                if unit == vdata.group.units[vdata.unit.cur] then
                    e_callsign:setText(callsign)
                end
            end
        end
        c_callsign:setVisible(westernCountry)
        e_callsignGroupNum:setVisible(westernCountry)
        e_callsignUnitNum:setVisible(westernCountry)
        e_callsign:setVisible(not westernCountry)
    end
end

-------------------------------------------------------------------------------
--возвращает название текущего вида helicopter/plane
function getView()
    return __view__
end

-------------------------------------------------------------------------------
--установка вида helicopter/plane
function setView(view)
    if (view ~= 'helicopter') and (view ~= 'plane') then
        print('setView error: "' .. tostring(view or '') ..  '" only "helicopter" or "plane" allowed')
        assert(0)
    else
        local oldCountry = vdata.country 
		vdata ={}
        vdata.country = oldCountry
		setData(vdatas[view])
		_tabs:selectTab('route')
		vdata.unit.number = 1
		vdata.unit.cur = 1
	
		panel_route.setGroup(nil)
		panel_suppliers.setGroup(nil)
		panel_triggered_actions.setGroup(nil)
		panel_payload.vdata.group = nil
		panel_targeting.vdata.group = nil
		panel_summary.vdata.group = nil
		panel_route.show(true)
		setSafeMode(true)
		panel_route.setSafeMode(true)

        if __view__ ~= view then
            switchView(view)
        end
        
        if vdata.type and (vdata.skills[vdata.unit.cur] == crutches.getPlayerSkill()
             or vdata.skills[vdata.unit.cur] == crutches.getClientSkill()) then 
             
            local unitTypeDesc = DB.unit_by_type[vdata.type]            
            if (unitTypeDesc.Navpoint_Panel == true) then
                _tabs:showTab('navPoint')
            else
                _tabs:hideTab('navPoint')
            end

            if (unitTypeDesc.Fixpoint_Panel == true) then
                _tabs:showTab('fixPoint')
            else
                _tabs:hideTab('fixPoint')
            end
        else
            _tabs:hideTab('fixPoint')
			_tabs:hideTab('navPoint')
        end

    end
end

-------------------------------------------------------------------------------
--смена вида helicopter/plane
function switchView(view)
    __view__ = view
    window:setText(cdata.title[__view__])

	vdata.type = nil

    fillCountries(true)
end

-------------------------------------------------------------------------------
-- append one array to another
function appendTable(res, new)
    for i, v in ipairs(new) do
        table.insert(res, v)
    end
end

-------------------------------------------------------------------------------
-- returns table which consists of all elements from both tables
function combineTables(t1, t2)
    local t = { }
    appendTable(t, t1)
    appendTable(t, t2)
    return t
end

-------------------------------------------------------------------------------
-- enabling / disabling frequency edit box
local function updateEnableFrequencyEditBox()
	if 	vdata.group and
		vdata.group.communication then
		local firstUnit = vdata.group.units[1]
		local unitType = firstUnit.type
		local unitTypeDesc = DB.unit_by_type[unitType]
		if firstUnit.skill == crutches.getPlayerSkill() or firstUnit.skill == crutches.getClientSkill() then
			assert(unitTypeDesc.HumanRadio ~= nil)
			if unitTypeDesc.HumanRadio.editable then
				e_frequency:setEnabled(true)
			else
				e_frequency:setEnabled(false)
			end
		else
			e_frequency:setEnabled(true)
		end
	else
		e_frequency:setEnabled(false)
	end
end


local function conditionInspectionFrequency(firstUnit, unitType)
    if  module_mission.mission.version < 10 then
        return (firstUnit.skill == crutches.getPlayerSkill() or firstUnit.skill == crutches.getClientSkill()) 
    else
        return true
    end
end

-------------------------------------
--проверка введенной частоты по диапазону допустимых значений для юнита данного типа
local function isFrequencyValid(group)
	if (group == nil) or (group.units == nil) or (group.units[1] == nil) then
		return true
	end
	local firstUnit = group.units[1]
	local unitType = firstUnit.type
	local unitTypeDesc = DB.unit_by_type[unitType]
    -- проверка частот для ботов отключена
 --   if conditionInspectionFrequency(firstUnit, unitType) then
--		if unitTypeDesc.HumanRadio and unitTypeDesc.HumanRadio.editable then
    if (firstUnit.skill == crutches.getPlayerSkill() or firstUnit.skill == crutches.getClientSkill()) then
		assert(unitTypeDesc.HumanRadio ~= nil)
		if unitTypeDesc.HumanRadio.editable then
            if (group.frequency) then
                if unitTypeDesc.HumanRadio.rangeFrequency then
                    local result = false
                    for k,v in base.pairs(unitTypeDesc.HumanRadio.rangeFrequency) do
                        if group.frequency >= v.min and group.frequency <= v.max then
                            result = true
                        end
                    end
                    return result
                else
                    return 	(unitTypeDesc.HumanRadio.minFrequency == nil or group.frequency >= unitTypeDesc.HumanRadio.minFrequency)
                            and
                            (unitTypeDesc.HumanRadio.maxFrequency == nil or group.frequency <= unitTypeDesc.HumanRadio.maxFrequency)
                end            
            else
                return false
            end
		else
			return true
		end
	else
		return true
	end
end

-------------------------------------------------------------------------------
-- setting the default frequency for group
function setDefaultRadio(a_allDefault)
	if not vdata.radioSet or a_allDefault == true then
		local defaultFrequency, defaultModulation = getDefaultRadio()
		assert(defaultFrequency ~= nil)
		assert(defaultModulation ~= nil)
		vdata.frequency = defaultFrequency
		vdata.modulation = defaultModulation
		if vdata.group then
			vdata.group.frequency = defaultFrequency
			vdata.group.modulation = defaultModulation
		end	
		e_frequency:setText(vdata.frequency)
		t_modulation:setText(cdata.modulationName[vdata.modulation])
	end
    
    if vdata.group then
        if isFrequencyValid(vdata.group) then
            e_frequency:setSkin(validFrequencyEditBoxSkin)
        else
            e_frequency:setSkin(invalidFrequencyEditBoxSkin)    
        end
    end    
	updateEnableFrequencyEditBox()
end

-------------------------------------------------------------------------------
-- change type of all units
function changeType(type)
    vdata.type = type
	if updateAutoTask() then
		panel_route.onGroupTaskChange()
	end
    local unitDef = DB.unit_by_type[type]
    local maxFuel = unitDef.MaxFuelWeight

	if (vdata.group) then
        local oldType = vdata.group.units[1].type
		for i = 1, vdata.unit.number do
			local unit = vdata.group.units[i]
			unit.type = type
            
            if (humanControlledAircrafts[unit.type] == nil) and  (vdata.skills[i] == crutches.getPlayerSkill()) then
                vdata.skills[vdata.unit.cur] = defaultAiSkill
                unit.skill = vdata.skills[vdata.unit.cur]
            end                      
            
            if oldType ~= type then
                local unitTypeDesc = DB.unit_by_type[type]
                if (unitTypeDesc.AddPropAircraft ~= nil) then
                    unit.AddPropAircraft = {}         
                    panel_loadout.update()    
                    panel_paramFM.setData(unitTypeDesc.AddPropAircraft, unit)
                else
                    unit.AddPropAircraft = nil 
                end                
            end
            
			-- Разгружаем пилоны
			unit.payload.pylons = {}
			unit.payload.fuel = maxFuel
		
			--по просьбе авиаторов не доливаем P-51
			if (unitDef.defFuelRatio) then
                unit.payload.fuel = unitDef.defFuelRatio * maxFuel
			end
			panel_payload.setDefaultLivery(unit)
		end

		for k,v in pairs(vdata.group.units) do
			if (v.skill == crutches.getPlayerSkill()) then
				panel_failures.change_player_plane(true, type)
				if (panel_failures.isVisible() == true) then
					panel_failures.show(true)
				end
			end
		end
	
		module_mission.setDefaultChaffFlare(vdata.group)
		panel_route.applyTypeRestrictions(vdata.group)
		panel_route.vdata.unit = vdata.group.units[vdata.unit.cur]
	
		local wpt = panel_route.vdata.wpt
		if wpt.linkUnit then
			module_mission.relinkChildren(wpt.linkUnit)
		end

        panel_route.updateAltSpeed()
		panel_route.update()
		MapWindow.updateSelectedGroup(vdata.group)	  

        local unit = vdata.group.units[vdata.unit.cur]    
        if unit.Radio then
            if oldType ~= type then
                unit.Radio = nil
            end    
            
            if (unit.skill == crutches.getPlayerSkill() or unit.skill == crutches.getClientSkill()) then
                panel_radio.update()
            end
        end     
	end
	
	-- пилоны должны быть разгружены ДО вызова panel_loadout.update()
	verifySingleInFlight(type)
	
	panel_route.onUnitTypeChange()
    fillSkillsList()
    updateSkill()
	setDefaultRadio(true)
	updateCallsignControls()
end

-------------------------------------------------------------------------------
--поиск итема в таблице по имени
local function findTableItemByName(table, item)
	for _tmp, v in pairs(table) do
		if v == item.Name then
		  return true
		end
	end

	return false
end

-------------------------------------------------------------------------------
--возвращает имя задачи по ID
local function getTaskName(taskWorldID)
	if not taskWorldIDs__ then
		-- создадим таблицу для быстрого поиска
		taskWorldIDs__ = {}
		for _tmp, task in pairs(DB.db.Units.Planes.Tasks) do
		  taskWorldIDs__[task.WorldID] = task.Name
		end
	end

	if not taskWorldIDs__[taskWorldID] then
		print('Task with WorldID ' .. taskWorldID .. ' is not presented in DB.db.Units.Planes.Tasks table!')
		return
	end

	return taskWorldIDs__[taskWorldID]  
end

-------------------------------------------------------------------------------
--возвращает ID задачи по имени
local function getTaskWorldID(taskName)
  if not taskNames__ then
    -- создадим таблицу для быстрого поиска
    taskNames__ = {}
    for _tmp, task in pairs(DB.db.Units.Planes.Tasks) do
      taskNames__[task.Name] = task.WorldID
    end
  end
  
  if not taskNames__[taskName] then
    print('Task ' .. taskName .. ' is not presented in DB.db.Units.Planes.Tasks table!')
  end
  
  return taskNames__[taskName]
end

-------------------------------------------------------------------------------
-- возвращает имя дефолтной задачи
function getDefaultTaskName()
  local defaultWorldID = DB.db.Units.Planes.DefaultTask.WorldID
 
  return getTaskName(defaultWorldID)
end

-------------------------------------------------------------------------------
--Формирование данных по всем странам и задачам.
function createCountryTasksTable()
  -- Формирование данных по всем странам и задачам.
  -- список задач для страны с разбивкой по самолетам 
  -- country_task_aircraft_list[__view__][CountyName] = {taskName = {planeName, planeName, ...},
  --                                        taskName = {planeName, planeName, ...}}  
    country_task_aircraft_list = {} 
  
  -- список задач для страны country_tasks[CountyName] = {taskName, taskName, ...}
    country_tasks = {} 
  
  -- по всем странам
	local defaultTaskName = getDefaultTaskName()
	assert(defaultTaskName)
	for i, view in ipairs(__views__) do
		for _tmp, country in pairs(DB.db.Countries) do
			local countryTasks = {}
			local taskAircraftsList = {[defaultTaskName] = {}} -- в списке задач должна присутствовать дефолтная задача

			-- по всем самолетам страны 
            local aircrafts
            if view == 'helicopter' then 
                aircrafts = country.Units.Helicopters.Helicopter
            else
                aircrafts = country.Units.Planes.Plane
            end
		
			for _tmp, plane in pairs(aircrafts) do
			  local unit = DB.unit_by_type[plane.Name]
			  
			  -- по всем задачам самолета
			  if not unit then
				print("check unit ",plane.CLSID,plane.Name)
			  else
				  if not unit.DefaultTask  then
				    base.error(unit.type..' has no default task!')
				  end
				 
				  default_tasks[unit.type] = unit.DefaultTask.Name
				  for _tmp, task in pairs(unit.Tasks) do 
					-- проверяем, существует ли уже такая задача в countryTasks
					if not findTableItemByName(countryTasks, task) then
					  table.insert(countryTasks, task.Name)
					end
                    
					-- добавляем самолет в список задачи
					taskAircraftsList[task.Name] = taskAircraftsList[task.Name] or {}
					table.insert(taskAircraftsList[task.Name], unit.type)							
				  end
				  -- добавляем самолет в список дефолтной задачи
					if not findTableItemByName(taskAircraftsList[defaultTaskName], unit) then
					  table.insert(taskAircraftsList[defaultTaskName], unit.type)
					end
			  end
			end

			-- сортируем самолеты по именам
			for _tmp, u in pairs(taskAircraftsList) do
			  table.sort(u)
			end
			-- сортируем задачи по именам
			table.sort(countryTasks)
			-- добавляем дефолтную задачу на первое место
			table.insert(countryTasks, 1, defaultTaskName)
					
			country_tasks[view] = country_tasks[view] or {}
			country_task_aircraft_list[view] = country_task_aircraft_list[view] or {}
			country_tasks[view][country.Name] = countryTasks
			country_task_aircraft_list[view][country.Name] = taskAircraftsList
		end
	end
end

-------------------------------------------------------------------------------
--закрытие окна
function close()
    panel_paramFM.show(false)
	panel_radio.show(false)
	panel_failures.show(false)
	panel_route.show(false)
    panel_wpt_properties.show(false)
	panel_loadout.show(false)
	panel_payload.show(false)
	panel_targeting.show(false)
	panel_summary.show(false)
	panel_triggered_actions.show(false)
	panel_fix_points.show(false)
    panel_nav_target_points.show(false)
	MapWindow.setState(MapWindow.getPanState())
	show(false)
	toolbar.setAirplaneButtonState(false)
	panel_units_list.show(false)
	MapWindow.unselectAll()
end

-------------------------------------------------------------------------------
function setPlannerMission(planner_mission)
	if (planner_mission == true) then
		c_country:setEnabled(false)
		e_name:setEnabled(false)
		c_task:setEnabled(false)
		sp_of:setEnabled(false)
		c_type:setEnabled(false)
		c_skill:setEnabled(false)
		e_onboard_num:setEnabled(false)
		e_callsign:setEnabled(false)
		e_pilot:setEnabled(false)
		c_callsign:setEnabled(false)
		e_callsignGroupNum:setEnabled(false)
		e_callsignUnitNum:setEnabled(false)  
		hiddenCheckbox:setVisible(false)
		uncontrolledCheckBox:setVisible(false)
		lateActivationCheckBox:setVisible(false)
		e_group_condition:setVisible(false)
		sp_probability:setVisible(false)
	else
		c_country:setEnabled(true)
		e_name:setEnabled(true)
		c_task:setEnabled(true)
		c_type:setEnabled(true)
		c_skill:setEnabled(true)
		e_onboard_num:setEnabled(true)
		e_callsign:setEnabled(true)
		e_pilot:setEnabled(true)
		c_callsign:setEnabled(true)
		e_callsignGroupNum:setEnabled(true)
		e_callsignUnitNum:setEnabled(true)  
		hiddenCheckbox:setVisible(true)
		uncontrolledCheckBox:setVisible(vdata.group ~= nil and  vdata.group.route.points[1].type == panel_route.actions.takeoffParking)
		lateActivationCheckBox:setVisible(true)
		e_group_condition:setVisible(true)
		sp_probability:setVisible(true)
	end
end

-------------------------------------------------------------------------------
function setGroup(group)
	vdata.group = group
	groupVariant:initialize(vdata.group and vdata.group.variantProbability, 1)
end

-------------------------------------------------------------------------------
-- Открытие/закрытие панели
function show(b)
	setPlannerMission(base.isPlannerMission())
    
    if b == window:isVisible() then
        return
    end

	vdata.unit.cur = 1
  
  if b then
	--setPlannerMission(base.isPlannerMission())
	if vdata.group == nil then
		setDefaultAircraft()
	end

	groupVariant:initialize(vdata.group and vdata.group.variantProbability, 1)
    update()
    
    if not(vdata.group) then
        setDefaultRadio()
        commCheckBox:setState(vdata.communication)
		e_frequency:setEnabled(commCheckBox:getState())
    end
  else
    vdata.group = nil	-- Во избежание нежелательной связи с группой при следующем открытии.
    panel_paramFM.show(false)
	panel_radio.show(false)
    panel_route.show(false)
    panel_wpt_properties.show(false)
    panel_loadout.show(false)
    panel_payload.show(false)
    panel_targeting.show(false)
    panel_summary.show(false)
	panel_triggered_actions.show(false)
  end
  window:setVisible(b)
end

-------------------------------------------------------------------------------
-- Загрузка данных из файла
function load(fName)
    base.dofile(fName)
    vdata = base.vdata
end

-------------------------------------------------------------------------------
-- Сохранение данных в файле
function save(fName)
    local f = base.io.open(fName, 'w')
    if f then
        local s = S.new(f)
        s:serialize_simple('vdata', vdata)
        f:close()
    end
end

-------------------------------------------------------------------------------
function getUnitType()
  return vdata.type
end

-------------------------------------------------------------------------------
function getUnitTaskName()
  return vdata.task
end

-------------------------------------------------------------------------------
function getUnitNumber()
  return vdata.unit.cur
end

-------------------------------------------------------------------------------
-- возвращает таблицу [номер пилона] = {CLSID = launcherCLSID}
function getUnitPylons()
  local pylons = {}
  
  if vdata.group then
    local unit = vdata.group.units[getUnitNumber()]
    if unit and unit.payload and unit.payload.pylons then
      pylons = unit.payload.pylons
    end
  end
  
  return pylons
end

-------------------------------------------------------------------------------
-- устанавливает подвеску на вертолете
-- таблица [pylonNumber] = launcherCLSID
function setUnitPayload(pylons, payloadName)
  if vdata.group then
    local unit = vdata.group.units[getUnitNumber()]
    unit.payload = unit.payload or {}
    unit.payload.name = payloadName
    unit.payload.pylons = {}
    unit.payload.pylonslauncher = {} -- by uboats
    for pylonNumber, launcherCLSID in pairs(pylons) do
      unit.payload.pylons[pylonNumber] = {CLSID = launcherCLSID}
      unit.payload.pylonslauncher[pylonNumber] = base.get_weapon_launcher_by_clsid(launcherCLSID) -- by uboats
    end
  end
end

-------------------------------------------------------------------------------
-- для установки извне
function setCountry(c)
    vdata.country = c
    updateCountry()

    fillTasksCombo(country_tasks[__view__][vdata.country])
    setTask()

    fillAircraftsCombo()

	setDefaultAircraft()
    
    panel_payload.update()
	updateTask()
	updateType()
    fillSkillsList()
	fillComboCallsigns()
	updateCallsignControls()
    
    verifyTabs()
end

-------------------------------------------------------------------------------
--смена страны
function changeCountry(c)
    panel_ship.setCountry(c)
    panel_static.setCountry(c)
    panel_vehicle.setCountry(c)
    
    vdata.country = c
    fillTasksCombo(country_tasks[__view__][vdata.country])
    setTask()

    U.fill_combo(c_type, country_task_aircraft_list[__view__][vdata.country][vdata.task])
	setType()

    if vdata.group then
		if vdata.group.boss.name ~= vdata.country then
			-- В связи со сменой страны нужно также поменять типы юнитов и цвет группы.
			-- В связи со сменой страны нужно также оставить в группе только умалчиваемые юниты страны.
			-- Исключаем группу из старой страны.
			for i,v in pairs(vdata.group.boss[__view__].group) do
				if v == vdata.group then
					table.remove(vdata.group.boss[__view__].group, i)
					break
				end
			end
			-- Включаем группу в новую страну.		
			for i,v in pairs(module_mission.mission.coalition) do
				local boss = vdata.group.boss
				for j,u in pairs(v.country) do
					if u.name == vdata.country then
						vdata.group.boss = u
						table.insert(u[__view__].group, vdata.group)
						-- Изменяем цвета объектов карты в группе
						vdata.group.color = u.boss.color
						break
					end
				end
				if vdata.group.boss ~= boss then
					break
				end
			end

			for i = 1, vdata.unit.number do
				local unit = vdata.group.units[i]
				panel_payload.setDefaultLivery(unit)
			end
		end

        -- Пересоздаем объекты карты, поскольку изменились цвета и условные знаки.
        panel_loadout.update()
        panel_targeting.update()
        panel_payload.update()
		panel_units_list.updateRow(vdata.group)

        -- если у группы первой точкой стоит взлет с полосы или стоянки, 
        -- то надо проверить на аэродроме чьей коалиции она находится
        local wpt = vdata.group.route.points[1]
        if panel_route.isAirfieldWaypoint(wpt.type) then
            panel_route.attractToAirfield(wpt, vdata.group)
        end
        
    end
	fillAircraftsCombo()
    if vdata.group == nil then
		setDefaultAircraft()
	end
    
    panel_payload.update()
	updateTask()
	updateType()
    fillSkillsList()
	fillComboCallsigns()
	updateCallsignControls()
    
    module_mission.updateTitleWaypoints(vdata.group)

	panel_route.onGroupCountryChange()
    verifyTabs()
end

-------------------------------------------------------------------------------
-- disable editing of unsafe elements
function setSafeMode(enable)
    local e = not enable

    sp_unit:setEnabled(e)
    sp_of:setEnabled(e)
    _tabs:setEnabled(e)
end

-------------------------------------------------------------------------------
--установка задачи
function setTask()
	for k,v in pairs(country_tasks[__view__][vdata.country]) do
		if (v == vdata.task) then
			return
		end
	end

	vdata.task = country_tasks[__view__][vdata.country][1]
    if vdata.group then
        if vdata.group.task ~= vdata.task then
            vdata.group.task = vdata.task
        end
    end
	return
end

-------------------------------------------------------------------------------
--установка типа ЛА
function setType()
	for k,v in pairs(country_task_aircraft_list[__view__][vdata.country][vdata.task]) do
		if (v == vdata.type) then
			return
		end
	end

	changeType(country_task_aircraft_list[__view__][vdata.country][vdata.task][1])
	return
end

-------------------------------------------------------------------------------
-- check if unit can be played by human
function isPlayableUnit()
    if not vdata.group then
        return true
    else
        return (1 == vdata.unit.cur)
    end
end

-------------------------------------------------------------------------------
-- returns true if value exists in list
function isValueInList(list, value)
    for _tmp, v in ipairs(list) do
        if v == value then
            return true
        end
    end
    return false
end

-------------------------------------------------------------------------------
function isEnableSkill(skill)
	local res = false
	for k, v in pairs(skills) do
		if (v == skill) then
			res = true
		end
	end
	return res
end

-------------------------------------------------------------------------------
function isWesternCallsign(text)
	if base.type(text) == 'number' then 
		return false
	end
	return true
end

-------------------------------------------------------------------------------
function getNewCallsign(unit)
    local group = unit.boss
    local country = group.boss
    local callsigns = getUsedCountryCallsigns(country)

    local callsignBase = 100
    local westernCountry = U.isWesternCountry(country.name)
    if westernCountry then
        local groupId = 1
        local unitId
        for i,_unit in ipairs(group.units) do 
            if unit == _unit then 
                unitId = i
            end
        end
        if unitId == nil then 
            --print('error, can not determine unit number')
            unitId = #group.units + 1 -- юнит в процессе создания, он еще не включен в группу
        end
        if unitId == 1 then
            while true do
                for k,v in pairs(getCallnames(group.boss.id, unit.type)) do
                    local callsign = v.Name .. tostring(groupId) .. tostring(unitId)				
                    if callsigns[callsign] == nil then
                        --print('choosing new callsign "' .. callsign .. '"')
                        return callsign, v.Name, groupId, unitId
                    else
                        --print('callsign "' .. callsignName .. '" already present, skipping')                
                    end
                end
                groupId = groupId + 1
                if groupId > 9 then
                    print('error, can not create new callsign, groupId > 9')
                end
            end
        else
            local unitsCount = #group.units
            local callsignName
            if (base.type(group.units[1].callsign) ~= 'table') then
                callsignName = string.match(group.units[1].callsign, '%D+') or group.units[1].callsign
                groupId =  string.match(group.units[1].callsign, '%d') or ''
            else
                callsignName    = group.units[1].callsign.name
                groupId         = group.units[1].callsign[1]
            end    
            
            local callsign =  callsignName .. groupId .. tostring(unitId)
            return callsign, callsignName, groupId, unitId
        end
        print('error, can not create new callsign')        
    else
        table.sort(callsigns)
        
        if #callsigns > 1 then
            for i, callsign in ipairs(callsigns) do
                if callsign >= callsignBase then -- фильтруем неправильные позывные
                    if math.abs( (callsigns[i+1] or callsign) - callsign) > 1 then -- нашли дырку в номерах позывных
                        return callsign + 1
                    end
                end
            end
            return callsigns[#callsigns] +1
        else
            if #callsigns == 0 then -- позывных нет
                return callsignBase -- возвращаем первый возможный позывной
            else -- ровно один позывной
                return callsigns[1] + 1 -- возвращаем следующий номер
            end
        end
    end
end

-------------------------------------------------------------------------------
--при смене типа ЛА устанавливает задачу по умолчанию для нового типа ЛА, если она не менялась вручную
function updateAutoTask()
	if 	(vdata.group and not vdata.group.taskSelected)
		or (vdata.group == nil) then	
		vdata.task = default_tasks[vdata.type]    
		c_task:setText(vdata.task)
		if vdata.group then
			if vdata.group.task ~= vdata.task then
				vdata.group.task = vdata.task
				return true
			end
		end
	end
	return false
end

-------------------------------------------------------------------------------
--возвращает позывной соответствующий переданной стране
function getUsedCountryCallsigns(country)
    local callsigns = {}
    local westernCountry = U.isWesternCountry(country.name)
    if westernCountry then
        for _tmp1, type in ipairs({'plane', 'helicopter'}) do
			for _tmp2, group in ipairs(country[type].group) do
				for _tmp3, unit in ipairs(group.units) do
					if(unit.callsign) then
						callsigns[unit.callsign] = ( callsigns[unit.callsign] or 1) + 1
					end
				end
			end
        end
    else
        for _tmp1, type in ipairs(__views__) do
            for _tmp2, group in ipairs(country[type].group) do
                for _tmp3, unit in ipairs(group.units) do
                    local n = tonumber(unit.callsign)
				
                    if n then 
                        table.insert(callsigns, n)
                    end
                end
            end
        end
    end
    return callsigns
end

function isPlayerSkill(a_unit)
    return ((a_unit.skill == crutches.getPlayerSkill()) or (a_unit.skill == crutches.getClientSkill())) 
end

function isAddPropAircraft(unitTypeDesc)
    if (unitTypeDesc.AddPropAircraft ~= nil) then
        for k,v in base.pairs(unitTypeDesc.AddPropAircraft) do
            if v.playerOnly == nil or v.playerOnly ~= true then
                return true
            else
                if (isPlayerSkill(vdata.group.units[vdata.unit.cur])) then
                    return true
                end
            end   
        end
    end    
    return false
end

-------------------------------------------------------------------------------
--для самолета игрока отображаем кнопку вызывающую панель отказов
function verifyTabs()
    local selectedItem = c_type:getSelectedItem()
    if selectedItem == nil then
        return
    end
	local type = selectedItem.type --c_type:getText()
	_tabs:hideTab('Radio')     
    
    if (vdata.group ~= nil) then
        local unitTypeDesc = DB.unit_by_type[vdata.group.units[vdata.unit.cur].type]
        if (isAddPropAircraft(unitTypeDesc)) then
            _tabs:showTab('paramFM')
            
            panel_loadout.update()
            panel_paramFM.setData(unitTypeDesc.AddPropAircraft, vdata.group.units[vdata.unit.cur])
        else
            if _tabs:getSelectedTab() == 'paramFM' then
                _tabs:selectTab('route')
            end
            _tabs:hideTab('paramFM')               
        end
    else
        _tabs:hideTab('paramFM')
    end        

	if (vdata.skills[vdata.unit.cur] == crutches.getPlayerSkill()
          or vdata.skills[vdata.unit.cur] == crutches.getClientSkill()) then
		  
		_tabs:showTab('failures')
	
		local unitTypeDesc
		if (vdata.group ~= nil) then
			unitTypeDesc = DB.unit_by_type[vdata.group.units[vdata.unit.cur].type]
            
            if (unitTypeDesc.Navpoint_Panel == true) then
                _tabs:showTab('navPoint')
            else
                _tabs:hideTab('navPoint')
            end

            if (unitTypeDesc.Fixpoint_Panel == true) then
                _tabs:showTab('fixPoint')
            else
                _tabs:hideTab('fixPoint')
            end

			if unitTypeDesc.Waypoint_Panel ~= nil and unitTypeDesc.Waypoint_Panel == true
				or unitTypeDesc.Waypoint_Custom_Panel == true then
				_tabs:showTab('waypoints')
			else
				_tabs:hideTab('waypoints')
				if  _tabs:getSelectedTab() == 'waypoints' then
					_tabs:selectTab('route')
				end
			end

			if _tabs:getSelectedTab() == 'waypoints' then
                panel_wpt_properties.update()   
            end  
            
            if (unitTypeDesc.panelRadio ~= nil)	then
                _tabs:showTab('Radio')
                panel_radio.update()
				
                -- синхронизируем частоту
                local frequency = tonumber(e_frequency:getText())
                
                if not frequency then
                    setDefaultRadio(true)
                    frequency = tonumber(e_frequency:getText())
                end	
                
                panel_radio.update()
                panel_radio.setConnectFrequency(frequency)
            else                    
                if _tabs:getSelectedTab() == 'Radio' then
                    _tabs:selectTab('route')
                end     
            end
        end    
		panel_failures.update()
	else		
		local selectedTab = _tabs:getSelectedTab()
	
		if 	selectedTab == 'failures' or 
			selectedTab == 'waypoints' or 
			selectedTab == 'Radio' then
		
			_tabs:selectTab('route')
		end
	
		_tabs:hideTab('failures')
        _tabs:hideTab('waypoints')
        _tabs:hideTab('navPoint')
        _tabs:hideTab('fixPoint')
	end
end



-------------------------------------------------------------------------------
--Установка самолета по умолчанию
function setDefaultAircraft()
	if (module_mission.isEnableAircraft()) then
		return
	end

	if (curHumanControlledAircrafts[1]) then
        vdata.type = curHumanControlledAircrafts[1]

        if updateAutoTask() then
            panel_route.onGroupTaskChange()
        end	
    else
      vdata.type = nil
	end
end

-------------------------------------------------------------------------------
--установка значений панели
function setData(a_data)
	U.copyTable(vdata, a_data)
end

-------------------------------------------------------------------------------
--			Заполнение контролов									         ---------------------------
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
--Заполнение контрола позывных
function fillComboCallsigns()
	local callsigns ={}
    local tmp_cal
    if vdata.group then
        tmp_cal = getCallnames(vdata.group.boss.id, vdata.type)
    end
	if (tmp_cal ~= nil) then
		for k, v in pairs(tmp_cal) do
			table.insert(callsigns, v.Name)
		end
	
		U.fill_combo(c_callsign, callsigns)
        c_callsign:setText(callsigns[1])
	end
end

function updateCountries()
    fillCountries()
	if (vdata.country) then
		changeCountry(vdata.country)
	end
end

-------------------------------------------------------------------------------
--заполнение списка стран
function fillCountries(notChange)
	function getIndexCountry(countries, country)
		local index = 0
		for k, v in ipairs(countries) do
			if (v == country) then
				index = k
			end
		end
		return index
	end

	countries = {}
	
	local c = CoalitionController.getActiveCountries()

	for i=1,#c do
		if country_task_aircraft_list[__view__][c[i] ] then
			if #country_task_aircraft_list[__view__][c[i] ][getDefaultTaskName()] > 0 then
				table.insert(countries, c[i])			
			end
		end
	end

	if #countries > 0 then
		U.fill_combo(c_country, countries)
		if (vdata.country) then
			if (getIndexCountry(countries, vdata.country) > 0) then					
			else
				vdata.country = countries[1] 
			end
		else
			vdata.country = countries[1] 
		end
	else
		vdata.country = nil
	end    
    
	if (vdata.country) and (not notChange) then
		changeCountry(vdata.country)
	end
end

-------------------------------------------------------------------------------
--заполнение списка задач
function fillTasksCombo(tasks)
  c_task:clear()
  
  for _tmp, taskName in ipairs(tasks) do
    local item = ListBoxItem.new(taskName)
    item.WorldID = getTaskWorldID(taskName)    
    c_task:insertItem(item)
  end
end

-------------------------------------------------------------------------------
--заполнение списка самолетов
function fillAircraftsCombo()
	function fill_combo(combo, t)  
        combo:clear()  
        curHumanControlledAircrafts = {}
        
        if not t then
            combo:setText("")
            return
        end

        local num = 1
        
        for i, type in ipairs(t) do
            local DisplayName = DB.getDisplayNameByName(type)
            local item = ListBoxItem.new(DisplayName)
            item.type = type
            item.DisplayName = DisplayName
            item.index = i
            combo:insertItem(item)
          
            if humanControlledAircrafts[type] ~= nil then
                item:setSkin(humanAircraftItemSkin)
                curHumanControlledAircrafts[num] = type
                num = num + 1
            end
        end
    end

	if vdata.group and vdata.group.taskSelected then
		fill_combo(c_type, country_task_aircraft_list[__view__][vdata.country][vdata.task])
	else
		fill_combo(c_type, country_task_aircraft_list[__view__][vdata.country][getDefaultTaskName()])
	end
end

-------------------------------------------------------------------------------
-- setup skills checkbox value
function fillSkillsList()
	function fill_combo(combo, t)    
        combo:clear()  
        if not t then
            combo:setText("")
            return
        end
        
        for i, text in ipairs(t) do
            local item = ListBoxItem.new(text)
            item.index = i
            combo:insertItem(item)
            
            if text == crutches.getPlayerSkill() then
              item:setSkin(playerItemSkin)
            end
        end
    end

	skills = {}

	if (1 == vdata.unit.cur) and (nil ~= humanControlledAircrafts[vdata.type]) then
		if (vdata.group ~= nil) then
			U.copyTable(skills, humanSkills)
		else
			U.copyTable(skills, clientSkills)
		end
	elseif (nil ~= clientControlledAircrafts[vdata.type]) then
		U.copyTable(skills, clientSkills)			
    else
        U.copyTable(skills, aiSkills)
    end	

    fill_combo(c_skill, skills)   
end

--обновление окна
function update()
	updateMisc() --обновление имени, пилота, пределов для номера самолета в звене 	
	updateCountry()

	local group = vdata.group

    if group then
        vdata.task = group.task
        hiddenCheckbox:setState(group.hidden)
		uncontrolledCheckBox:setState(group.uncontrolled)
		lateActivationCheckBox:setState(group.lateActivation)
		e_group_condition:setEnabled(not group.lateActivation)
		sp_probability:setEnabled(not group.lateActivation)
		if not group.lateActivation then
			e_group_condition:setText(group.condition)
			sp_probability:setValue((group.probability or 1) * 100)
		end
	
        vdata.radioSet = group.radioSet
		vdata.frequency = group.frequency or vdata.frequency
		vdata.modulation = group.modulation or vdata.modulation
                
        verifySingleInFlight(group.units[1].type)
	
        updatePlayerSkill(vdata.skills[vdata.unit.cur])
        panel_route.vdata.unit = group.units[vdata.unit.cur]
        panel_route.update()
    end

	fillTasksCombo(country_tasks[__view__][vdata.country]) -- заполняем контрол задач
	updateTask()	-- обновляем контрол задач

	fillAircraftsCombo() -- заполняем контрол типов ЛА
	updateType()		-- обновляем контрол типов ЛА

    fillSkillsList()	-- заполняем контрол скилов
	updateSkill()	    -- обновляем контрол скилов
	updatePilot()

	fillComboCallsigns()
	updateCallsignControls() -- обновляем контролы позывных
    panel_fix_points.update()

	updateTaskComboBoxTheme()
	updateAutoTask()

    updateHeadingWidgets()
    updateHeading()
	verifyTabs()
end

function verifySingleInFlight(a_type)
    local unitDef = DB.unit_by_type[a_type]           
    if (unitDef.singleInFlight == true) then
        sp_of:setRange(1, 1) 
        sp_of:setValue(1)         
        onSpinUnitOf(sp_of)
    else
        sp_of:setRange(1, maxUnitCount) 
    end
    sp_of:setValue(vdata.unit.number)
end    
        
-------------------------------------------------------------------------------
--обновление цвета текста в списке задач: если задача ставится автоматом по типу ЛА - серый, если была выставлена вручную - черный
function updateTaskComboBoxTheme()
	local selectedItem = c_task:getSelectedItem()

	if vdata.group and vdata.group.taskSelected then
		selectedItem:setSkin(taskItemSkin)
	else
		selectedItem:setSkin(defaultTaskItemSkin)    
	end

	c_task:selectItem(selectedItem)
end

-------------------------------------------------------------------------------
--обновление имени, пилота, пределов для номера самолета в звене
function updateMisc()
	e_name:setText(vdata.name) 
	sp_unit:setValue(vdata.unit.cur)
	sp_unit:setRange(1, vdata.unit.number)
	sp_of:setValue(vdata.unit.number) 		
end

-------------------------------------------------------------------------------
--обновление имени, пилота, пределов для номера самолета в звене
function updatePilot()
	e_pilot:setText(vdata.pilots[vdata.unit.cur]) 
end

-------------------------------------------------------------------------------
--обновление типов ЛА
function updateType()
    local isEnable = false
    local isEnableLast = false
	if (vdata.skills[1] == crutches.getPlayerSkill()) then
		isEnable = true
	else
		for k, v in pairs(country_task_aircraft_list[__view__][vdata.country][vdata.task]) do
			if (v == vdata.type) then
				isEnable = true
			end   
            
            if (v == last_data[__view__].type) then
				isEnableLast = true
			end     
		end
	end
    
    if isEnable == false then
        vdata.type = nil
    end

	if (vdata.type == nil) then
		if (last_data[__view__].type ~= nil) and (isEnableLast == true) then
			vdata.type = last_data[__view__].type
		else
			vdata.type = country_task_aircraft_list[__view__][vdata.country][vdata.task][1]
		end
	end    

    setTypeItem(vdata.type)
	last_data[__view__].type	 	= vdata.type
end

function setTypeItem(a_type)    
    local counter = c_type:getItemCount() - 1
		
    for i = 0, counter do
        local item = c_type:getItem(i)        
        if item.type == a_type then
            c_type:selectItem(item)
            break
        end
    end
end

-------------------------------------------------------------------------------
--обновление задач
function updateTask()
    if country_task_aircraft_list[__view__][vdata.country][vdata.task] == nil then
        vdata.task = nil
    end
    
	if (vdata.task == nil) then
		if (last_data[__view__].task ~= nil) then
			vdata.task = last_data[__view__].task
		else
			vdata.task = country_tasks[getView()][vdata.country][1]
		end
	end
	c_task:setText(vdata.task)
	last_data[__view__].task	 	= vdata.task
end

-------------------------------------------------------------------------------
--обновление скила
function updateSkill()
	if (vdata.skills ~= nil) then
		if (vdata.skills[vdata.unit.cur] == nil) then
			if ((last_data[__view__].skill ~= nil) and (isEnableSkill(last_data.skill))) then 
				if ( last_data[__view__].skill ~= crutches.getPlayerSkill()) then
					vdata.skills[vdata.unit.cur] = last_data[__view__].skill 
				else
					vdata.skills[vdata.unit.cur] = defaultAiSkill
				end
			else
				vdata.skills[vdata.unit.cur] = defaultAiSkill
			end
		else
			if not(isEnableSkill(vdata.skills[vdata.unit.cur])) then
				vdata.skills[vdata.unit.cur] = defaultAiSkill
			end
		end
	end
  
    if vdata.group then
        vdata.group.units[vdata.unit.cur].skill = vdata.skills[vdata.unit.cur]
    end
    
	c_skill:setText(vdata.skills[vdata.unit.cur])
	last_data[__view__].skill		= vdata.skills[vdata.unit.cur] 
	
	panel_units_list.updateBtnPlayerUnit()
end

-------------------------------------------------------------------------------
--обновление страны
function updateCountry()
    if (vdata.country == nil) then
        vdata.country = countries[1]
    else
        local enableC = false
        for k,v in pairs(countries) do
            if (v == vdata.country) then
                enableC = true
            end
        end 
        if (enableC == false) then
            vdata.country = countries[1]
        end
	end
	c_country:setText(vdata.country)
end

-------------------------------------------------------------------------------
--обновление позывных
function updateCallsignControls()
	local callsign, onboardNum = '', ''
    local countryName = vdata.country --vdata.group.boss
    local westernCountry = U.isWesternCountry(countryName)
    if vdata.group then
		local firstUnit = vdata.group.units[1]
		local numericPart = DB.db.doesCallsignHasNumericPart(vdata.group.boss.id, DB.unit_by_type[firstUnit.type].attribute)
	
		e_onboard_num:setText(vdata.group.units[vdata.unit.cur].onboard_num)
        panel_payload.updateOnboardNumber(vdata.group.units[vdata.unit.cur].onboard_num)
		commCheckBox:setState(vdata.communication)
		commCheckBox:onChange()
		e_frequency:setText(vdata.frequency)
		t_modulation:setText(cdata.modulationName[vdata.modulation])
	
        callsign = vdata.group.units[vdata.unit.cur].callsign
	
        if westernCountry then -- новая страна западная 
            local str = string.match(callsign, '%D+') or callsign          
            c_callsign:setText(str)
            e_callsignGroupNum:setText(string.match(callsign, '%d'))
            e_callsignUnitNum:setText(string.match(callsign, '%d$'))
        else -- новая страна восточная
            e_callsign:setText(callsign)
        end
	
		t_callsign:setVisible(true)
        c_callsign:setVisible(westernCountry)
        e_callsignGroupNum:setVisible(westernCountry and numericPart)
        e_callsignUnitNum:setVisible(westernCountry and numericPart)
        e_callsign:setVisible(not westernCountry)
	else
		t_callsign:setVisible(false)
		c_callsign:setVisible(false)
        e_callsignGroupNum:setVisible(false)
        e_callsignUnitNum:setVisible(false)
        e_callsign:setVisible(false)
    end
end

-------------------------------------------------------------------------------
--обновление при изменении самолета игрока
function updatePlayerSkill(skill)
    if vdata.group then
        if skill == crutches.getPlayerSkill() then 
            -- уже есть юнит со скилом игрока, надо сбросить скил этого юнита и поставить скил игрока новому юниту
            if module_mission.playerUnit then
                module_mission.playerUnit.skill = humanSkills[1]
                
                if (module_mission.playerUnit ~= vdata.group.units[vdata.unit.cur]) then
                    -- сбрасываем точки
                    module_mission.remove_INUFixPoint_All(module_mission.playerUnit.boss)
                    module_mission.remove_NavTargetPoint_All(module_mission.playerUnit.boss)
                end
            end
            module_mission.playerUnit = vdata.group.units[vdata.unit.cur]
        end
        vdata.group.units[vdata.unit.cur].skill = vdata.skills[vdata.unit.cur]
    end
end

function updateHeadingWidgets()
    if vdata.group and (vdata.group.route.points[1].type.action == 'From Ground Area'  or vdata.group.route.points[1].type.action == 'From Ground Area Hot') then
        t_heading:setVisible(true)
        sp_heading:setVisible(true)
        d_heading:setVisible(true)
    else
        t_heading:setVisible(false)
        sp_heading:setVisible(false)
        d_heading:setVisible(false)
    end
end


-------------------------------------------------------------------------------
--Обновление поворота юнита
function updateHeading()
    local heading = 0
    if vdata.group then
        if not (vdata.group.route.points[1].type.action == 'From Ground Area'  or vdata.group.route.points[1].type.action == 'From Ground Area Hot') then
            if (#vdata.group.route.points > 1) 
                and (vdata.group.route.points[1].airdromeId == nil)then
            
                local p1 = vdata.group.route.points[1]
                local p2 = vdata.group.route.points[2]
            
                if (p1.x == p2.x) and (p1.y == p2.y) then
                    heading = 0
                else
                    heading = MapWindow.getAngle(p1, p2) 			
                end
        
                for k,v in pairs(vdata.group.units) do
                    v.heading = heading
                end
            else
                for k,v in pairs(vdata.group.units) do
                    v.heading = v.heading or 0
                end
            end
        else
            local degrees = UC.toDegrees(vdata.group.units[vdata.unit.cur].heading)   
            sp_heading:setValue(degrees);
            d_heading:setValue(degrees);
        end
        
		for k,unitObj in pairs(vdata.group.mapObjects.units) do
			if OptionsData.getIconsTheme() == 'russian' then	
				local unitMapObject = vdata.group.mapObjects.units[vdata.unit.cur]
				local classInfo = MapWindow.getClassifierObject(unitMapObject.classKey)
			
				if classInfo and classInfo.rotatable then					
					unitObj.angle = MapWindow.headingToAngle(vdata.group.units[k].heading) -- в объектах карты храним все в градусах
				
					if k == 1 then
						vdata.group.mapObjects.route.points[1].angle = MapWindow.headingToAngle(vdata.group.units[1].heading)												
					end									
				end
			end
			
			if unitObj.picModel then
				unitObj.picModel:setOrientationEuler(MapWindow.headingToAngle(vdata.group.units[k].heading), 0, 0)
			end
		end
		
		module_mission.update_group_map_objects(vdata.group)
	end
end



-------------------------------------------------------------------------------
--			Обработка действий контролов									 ---------------------------
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
--увеличение числа самолетов в группе
function onSpinUnitOf(self)
	local n = self:getValue()
	if n < vdata.unit.number then
		for i = vdata.unit.number, n + 1, -1 do
			table.remove(vdata.pilots, i)
			table.remove(vdata.skills, i)
			if vdata.group then
				-- Нужно также удалить соответствующие юниты из миссии
				module_mission.remove_unit(vdata.group.units[i])
			end
		end
	elseif n > vdata.unit.number then
		local numAddAircrafts = n - vdata.unit.number
		local roadnet = nil
		local bAddUnit = true
		if (vdata.group.route.points[1].airdromeId) then
			roadnet = MapWindow.listAirdromes[vdata.group.route.points[1].airdromeId].roadnet		
			bAddUnit = (numAddAircrafts <= mod_parking.getFreeParkingForAircraft(vdata.group, roadnet))
		end
		
		if (vdata.group.route.points[1].helipadId) then	
			bAddUnit = (numAddAircrafts <= mod_parking.getFreeParkingOnHelipad(vdata.group, vdata.group.route.points[1].helipadId))
		end
		
		if bAddUnit then
			for i=vdata.unit.number+1,n do
				vdata.pilots[i] = cdata.pilotList[U.find_diff(cdata.pilotList, vdata.pilots)]
				vdata.skills[i] = getSkillNewUnit(vdata.skills[vdata.unit.cur])
				if vdata.group then
					-- Нужно также добавить соответствующие юниты в миссию
					local unit = module_mission.insert_unit(
							vdata.group, vdata.type, 
							vdata.skills[i], i)
					U.copyTable(unit.payload, vdata.group.units[vdata.unit.cur].payload)
					local name = module_mission.check_unit_name(vdata.pilots[#vdata.pilots])
					module_mission.renameUnit(unit, name)
					vdata.pilots[n] = name
					unit.livery_id = vdata.group.units[vdata.unit.cur].livery_id
					
					if vdata.group.units[vdata.unit.cur].Radio then
						setDataRadio(unit, vdata.group.units[vdata.unit.cur])
						setDataAddProp(unit, vdata.group.units[vdata.unit.cur])
					else
						setDataRadio(unit, getClientParamsforCopy(i))
						setDataAddProp(unit, getClientParamsforCopy(i))
					end
				end
			end
			if (panel_route.isTakeOffParking(panel_route.vdata.group.route.points[1].type))
				and panel_route.vdata.group.route.points[1].airdromeId then
			
				mod_parking.addUnitsInGroupOnAirport(vdata.group, roadnet, numAddAircrafts)
			end
		else
			MsgWindow.warning(_('No parking for this aircraft.'),  _('WARNING'), 'OK'):show()
		
			n = vdata.unit.number
			self:setValue(n)
		end
	
	end
	vdata.unit.number = n
	vdata.unit.cur = vdata.unit.number
	sp_unit:setRange(1, vdata.unit.number)
	sp_unit:setValue(vdata.unit.cur)

    fillSkillsList()
	updateSkill()	    -- обновляем контрол скилов
	updatePilot()	
	updateCallsignControls() -- обновляем контролы позывных

    if vdata.group then
        local unit = vdata.group.units[vdata.unit.cur]
        panel_payload.vdata.unit = unit
        panel_route.vdata.unit = unit
    end

	panel_targeting.update()
	panel_loadout.update()
	panel_payload.update()
	panel_route.update()

	if vdata.group then
		panel_units_list.updateRow(vdata.group, vdata.group.units[vdata.unit.cur])
		for i=1,vdata.unit.number do
			vdata.group.mapObjects.units[i].currColor = vdata.group.boss.boss.selectGroupColor
		end
		vdata.group.mapObjects.route.points[1].currColor = vdata.group.boss.boss.selectGroupColor
		vdata.group.mapObjects.units[vdata.unit.cur].currColor = vdata.group.boss.boss.selectUnitColor
		module_mission.update_group_map_objects(vdata.group)
		updateCallsignControls()
	end

	verifyTabs()
end

-------------------------------------------------------------------------------
--переключение текущего самолета в группе
function onSpinUnit(self)
	vdata.unit.cur = self:getValue()
    local unit = vdata.group.units[vdata.unit.cur]
    panel_loadout.update()  --выполнение занимает много времени #посмотреть

    if vdata.group then
        -- При переключении юнита нужно переключать и подсветку соответствующего объекта на карте
        for i=1,vdata.unit.number do
            vdata.group.mapObjects.units[i].currColor = vdata.group.boss.boss.selectGroupColor
        end
        vdata.group.mapObjects.units[vdata.unit.cur].currColor = vdata.group.boss.boss.selectUnitColor
        if vdata.unit.cur == 1 then
            vdata.group.mapObjects.route.points[1].currColor = vdata.group.boss.boss.selectUnitColor
        else
            vdata.group.mapObjects.route.points[1].currColor = vdata.group.boss.boss.selectGroupColor
        end
        module_mission.update_group_map_objects(vdata.group)
        local unit = vdata.group.units[vdata.unit.cur]
        panel_payload.vdata.unit = unit
        panel_route.vdata.unit = unit
        panel_route.update()
        panel_payload.update()
        updateCallsignControls()-- обновляем контролы позывных
		panel_units_list.updateRow(vdata.group, vdata.group.units[vdata.unit.cur])
    end
	fillSkillsList()
	updateSkill()	    -- обновляем контрол скилов
	updatePilot()	
    updateHeading()

    verifyTabs()
end

-------------------------------------------------------------------------------
--изменение имени
function onEditName(self)
    if vdata.group then
		vdata.name = module_mission.check_group_name(self:getText())
		module_mission.renameGroup(vdata.group, vdata.name)
		panel_units_list.updateRow(vdata.group, vdata.group.units[vdata.unit.cur])
	else
		vdata.name = self:getText()
	end
end

-------------------------------------------------------------------------------
--изменение страны
function onComboCountry(self)
	vdata.country = self:getText()
	changeCountry(vdata.country)
	e_onboard_num:onChange()
	changeCallsign()
	updateCountry() 
	updateSkill()
    panel_route.update()
end

-------------------------------------------------------------------------------
--изменение типа
function onComboType(self, item)
	if vdata.type == self:getSelectedItem().type  then
		return
	end
	vdata.type = self:getSelectedItem().type
    updateAutoTask()

	if vdata.group then
        for k,v in base.pairs(vdata.group.units) do
            v.payload.pylons = {}
        end
		changeType(vdata.type)
		changeCallsign()
		-- Пересоздаем объекты карты, поскольку изменились условные знаки.
		panel_payload.update()
		panel_loadout.update()       
	end
    
	fillSkillsList()	
	update()
	if vdata.group then
		panel_units_list.updateRow(vdata.group)
	end
end

-------------------------------------------------------------------------------
--изменение бортового номера
function onEditOnboardNumber(self)
	local nm = self:getText()
	if vdata.group then
		vdata.group.units[vdata.unit.cur].onboard_num = nm
        panel_payload.updateOnboardNumber(nm)
	end
end

function getCurOnboardNumber()
    if vdata.group then
        return vdata.group.units[vdata.unit.cur].onboard_num
    else
        return "0"
    end
end

function verify(group)
	return not isFrequencyValid(group) and _(cdata.invalidFreq)..' '..(group.frequency or "")..' '..cdata.MHz.."\n"
end

-------------------------------------------------------------------------------
--попытка закрыть окно
function onCloseAttempt(onCloseFunc)
	if 	panel_route.window:isVisible() and
		vdata.group ~= nil then
		panel_route.onCloseAttempt()
		local routeVerifyResult = panel_route.verify(vdata.group.route, vdata.group.lateActivation)
		local groupVerifyResult = verify(vdata.group)
		local verifyResult = (routeVerifyResult or groupVerifyResult) and (routeVerifyResult and routeVerifyResult..'\n' or '')..(groupVerifyResult or '')
            
		if verifyResult then
			local handler = MsgWindow.error(verifyResult..'\n'..cdata.continue_question, cdata.error, cdata.ok, cdata.cancel)
		
            function handler:onChange(buttonText)
                -- если не нажата кнопка OK, то окно me_aircraft не закроется
                if buttonText == cdata.ok then
                    onCloseFunc()
				end
            end
            
			handler:show()
            
			return false
		end
	end

	onCloseFunc()

	return true
end

-------------------------------------------------------------------------------
--закрытие окна
function onButtonClose(self)
	onCloseAttempt(function()
						close()
					end)
end

-------------------------------------------------------------------------------
--изменение задачи
function onComboTask(self)
	if vdata.group then
		vdata.group.taskSelected = true
		vdata.task = self:getText()
	else
		self:setText(vdata.task)
		return
	end

	updateTaskComboBoxTheme()
	fillAircraftsCombo()
	
    if vdata.group then
        vdata.group.task = vdata.task
        local changed = false
        -- Если тип юнита не соответствует новой задаче, то нужно выбрать умалчиваемый.
        for i,unit in pairs(vdata.group.units) do
            local found = false
            for j,aircraft in pairs(country_task_aircraft_list[__view__][vdata.country][vdata.task]) do
                if aircraft == unit.type then
                    found = true
                    break
                end
            end
            if not found then
                unit.type = country_task_aircraft_list[__view__][vdata.country][vdata.task][1]
                unit.CLSID = DB.unit_by_type[unit.type].CLSID
				vdata.type = unit.type
                unit.Radio = nil
                changed = true
            end
        end
        if changed then
            -- Разгружаем пилоны
            for i,unit in pairs(vdata.group.units) do
                unit.payload.pylons = {}
            end
            -- Пересоздаем объекты карты, поскольку изменились условные знаки
            changeType(vdata.type)
        end
        
        panel_loadout.update()
        panel_targeting.update()
		verifyTabs()
    else
        vdata.type = country_task_aircraft_list[__view__][vdata.country][vdata.task][1]
		updateAutoTask()
        setTypeItem(vdata.type)
    end

    fillSkillsList()
	updateType()
    changeCallsign()
	update()
    panel_payload.update()
	panel_route.onGroupTaskChange()
end

-------------------------------------------------------------------------------
--изменение пилота
function onEditPilot(self)
	local name = self:getText()
	local group = vdata.group
	if group then
		local unit = group.units[vdata.unit.cur]
		if unit then
			local newName = module_mission.check_unit_name(name)
			module_mission.renameUnit(unit, newName)
			name = newName
			panel_units_list.updateRow(vdata.group, vdata.group.units[vdata.unit.cur])
		end
	end
	vdata.pilots[vdata.unit.cur] = name
end

-------------------------------------------------------------------------------
--изменение скила
function onComboSkill(self)
	local skill = self:getText()

	if((vdata.skills[vdata.unit.cur] == crutches.getPlayerSkill()) 
		and (skill ~= crutches.getPlayerSkill())) then
		panel_failures.reset()			 -- сбрасываем неисправности
    end   
    
    if (((vdata.skills[vdata.unit.cur] == crutches.getPlayerSkill()) 
            or  (vdata.skills[vdata.unit.cur] == crutches.getClientSkill()))
		and ((skill ~= crutches.getPlayerSkill())
            and (skill ~= crutches.getClientSkill()))) then
            
        if vdata.group then  
            --сбрасываем точки
            module_mission.remove_INUFixPoint_All(vdata.group.units[vdata.unit.cur].boss)
            module_mission.remove_NavTargetPoint_All(vdata.group.units[vdata.unit.cur].boss)
        end
        _tabs:selectTab('route')
	end

	vdata.skills[vdata.unit.cur] = skill
	updatePlayerSkill(skill) 

    local type = c_type:getSelectedItem().type 
	if (humanControlledAircrafts[type] ~= nil) and (skill == crutches.getPlayerSkill()) then
		panel_failures.change_player_plane(false)
	end

    if vdata.group then
        local unit = vdata.group.units[vdata.unit.cur]
        if unit.Radio then
            if (skill ~= crutches.getPlayerSkill() and skill ~= crutches.getClientSkill()) then
                unit.Radio = nil
            end    
        end
		
		if (skill == crutches.getPlayerSkill() or skill == crutches.getClientSkill()) then
			panel_radio.update()
			setDataRadio(vdata.group.units[vdata.unit.cur], getClientParamsforCopy(vdata.unit.cur))
			setDataAddProp(vdata.group.units[vdata.unit.cur], getClientParamsforCopy(vdata.unit.cur))
		end

    end

    updateSkill()
	
	verifyTabs()

	setDefaultRadio()
end

function setDataAddProp(a_targetUnit, a_sourceUnit)
	if a_sourceUnit == nil or a_sourceUnit.AddPropAircraft == nil
		or a_targetUnit == nil then
		return
	end

	a_targetUnit.AddPropAircraft = {}
	base.U.recursiveCopyTable(a_targetUnit.AddPropAircraft, a_sourceUnit.AddPropAircraft)
end

function setDataRadio(a_targetUnit, a_sourceUnit)
	if a_sourceUnit == nil or a_sourceUnit.Radio == nil
		or a_targetUnit == nil then
		return
	end

	a_targetUnit.Radio = {}
	base.U.recursiveCopyTable(a_targetUnit.Radio, a_sourceUnit.Radio)
end

function getClientParamsforCopy(a_targetUnitIndex)

	if vdata.unit.cur and vdata.unit.cur ~= a_targetUnitIndex 
		and vdata.group.units[vdata.unit.cur]
		and (vdata.group.units[vdata.unit.cur].skill == crutches.getPlayerSkill() 
			or vdata.group.units[vdata.unit.cur].skill == crutches.getClientSkill())	then
		
		return vdata.group.units[vdata.unit.cur]
	end	
	

	for k, unit in base.ipairs(vdata.group.units) do
		if k ~= a_targetUnitIndex then
			if (unit.skill == crutches.getPlayerSkill() or unit.skill == crutches.getClientSkill()) then
				return unit
			end	
		end
	end
	
	return nil
end


-------------------------------------------------------------------------------
--изменение позывного
function onEditCallsign(self)
	local nm  = self:getText()

	if (string.len(nm) > 3) then
		local str = string.sub(nm,1,3)
		nm = str
		self:setText(nm)
	end

	if vdata.group then
		vdata.group.units[vdata.unit.cur].callsign = nm
	end
end

-------------------------------------------------------------------------------
--изменение номера группы в западном позывном
function onComboGroupNumCallsign(self)
	local nm  = self:getText()

	if (string.len(nm) > 3) then
		local str = string.sub(nm,1,3)
		nm = str
		self:setText(nm)
	end

	for k, unit in ipairs(vdata.group.units) do
        local callsign = unit.callsign
		print("callsign=",callsign)
        local newCallsign = c_callsign:getText()
							..e_callsignGroupNum:getText()
							..k
		print("newCallsign=",newCallsign)
        unit.callsign = newCallsign
    end
end

-------------------------------------------------------------------------------
--изменение позывного (комбобокса)
function onComboCallsign(self)
	local firstUnit = vdata.group.units[1]
	local text = self:getText()
    for k, unit in ipairs(vdata.group.units) do
        local callsign = unit.callsign
        local newCallsign = string.gsub(callsign, '%D+', text)
        unit.callsign = newCallsign
        if unit == vdata.group.units[vdata.unit.cur] then
            e_callsignGroupNum:setText(string.match(newCallsign, '%d')) 
            e_callsignUnitNum:setText(k)
        end
    end
end

-------------------------------------------------------------------------------
function onCheckComm(self)
	if vdata.group then
		vdata.group.communication = self:getState()
	end
	vdata.communication = self:getState()
	updateEnableFrequencyEditBox()
end

-------------------------------------------------------------------------------
function onUncontrolled(self)
	if vdata.group then
		vdata.group.uncontrolled = self:getState()
	end
end

-------------------------------------------------------------------------------
function onLateActivation(self)
	if vdata.group then
		vdata.group.lateActivation = self:getState()
		vdata.group.route.routeRelativeTOT = self:getState()
		panel_route.onLateActivationChanged()
		panel_summary.updateStartTime()
	end
end

-------------------------------------------------------------------------------
function onProbability(self)
	if vdata.group then
		vdata.group.probability = self:getValue() / 100
	end
end

-------------------------------------------------------------------------------
function onCondition(self)
	if vdata.group then
		vdata.group.condition = self:getText()
	end
end

------------------------------------------
--изменение частоты
function onEditFrequency(self)
	local text = self:getText()
	local textNew = string.gsub(text, "-", "")

	if (textNew ~= text) then
		text = textNew
		self:setText(text)
	end

	local frequency = tonumber(text) or 0
  
	setFrequency(frequency)					
  
	if (vdata.group and vdata.group.units and vdata.unit 
		and (DB.unit_by_type[vdata.group.units[vdata.unit.cur].type].panelRadio ~= nil))	then
		panel_radio.update()
        panel_radio.setConnectFrequency(frequency)
	end
end

function getCurUnit()
    if vdata.group then 
        return vdata.group.units[vdata.unit.cur]
    end
    return nil
end

------------------------------------------
--скил для нового юнита
function getSkillNewUnit(skill)
    if (skill == crutches.getPlayerSkill()) then
        return defaultAiSkill
    end
    return skill
end    

------------------------------------------
--
function GetGroupName(a_type)
    if a_type == 'plane' then
        return vdatas[ __views__[2] ].name
    else
        return vdatas[ __views__[1] ].name
    end    
end

------------------------------------------
--
function GetUnitName(a_type)
    if a_type == 'plane' then
        return vdatas[ __views__[2] ].pilots[1]
    else
        return vdatas[ __views__[1] ].pilots[1]
    end
end

------------------------------------------
--
function setFrequency(a_frequency)
	vdata.frequency = a_frequency
	vdata.radioSet = true
  
	if vdata.group then
		vdata.group.frequency = a_frequency
		vdata.group.radioSet = true
	end
  
  if isFrequencyValid(vdata.group) then
    e_frequency:setSkin(validFrequencyEditBoxSkin)
  else
    e_frequency:setSkin(invalidFrequencyEditBoxSkin)    
  end
end

function isVisible()
    return window:isVisible()
end   
    
