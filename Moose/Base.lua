--- BASE The base class for all the classes defined within MOOSE.
-- @module Base
-- @author Flightcontrol

Include.File( "Routines" )

local _TraceOn = true
local _TraceLevel = 1
local _TraceClass = {
	--DATABASE = true,
	--SEAD = true,
	--DESTROYBASETASK = true,
	--MOVEMENT = true,
	--SPAWN = true,
	--STAGE = true,
	--ZONE = true,
	--GROUP = true,
	--UNIT = true,
  --CLIENT = true,
	--CARGO = true,
	--CARGO_GROUP = true,
	--CARGO_PACKAGE = true,
	--CARGO_SLINGLOAD = true,
	--CARGO_ZONE = true,
	--CLEANUP = true,
	--MENU_CLIENT = true,
	--MENU_CLIENT_COMMAND = true,
	--ESCORT = true,
	}

--- The BASE Class
-- @type BASE
-- @field ClassName The name of the class.
-- @field ClassID The ID number of the class.
BASE = {

  ClassName = "BASE",
  ClassID = 0,
  Events = {}
}

--- The Formation Class
-- @type FORMATION
-- @field Cone A cone formation.
FORMATION = {
  Cone = "Cone" 
}

--- The base constructor. This is the top top class of all classed defined within the MOOSE.
-- Any new class needs to be derived from this class for proper inheritance.
-- @param self
-- @return #BASE
-- @usage
-- function TASK:New()
--
--     local self = BASE:Inherit( self, BASE:New() )
-- 
--     -- assign Task default values during construction
--     self.TaskBriefing = "Task: No Task."
--     self.Time = timer.getTime()
--     self.ExecuteStage = _TransportExecuteStage.NONE
-- 
--     return self
-- end
-- @todo need to investigate if the deepCopy is really needed... Don't think so.

function BASE:New()
	local Child = routines.utils.deepCopy( self )
	local Parent = {}
	setmetatable( Child, Parent )
	Child.__index = Child
	self.ClassID = self.ClassID + 1
	Child.ClassID = self.ClassID
	--Child.AddEvent( Child, S_EVENT_BIRTH, Child.EventBirth )
	return Child
end

--- This is the worker method to inherit from a parent class.
-- @param Child is the Child class that inherits.
-- @param Parent is the Parent class that the Child inherits from.
-- @return Child
function BASE:Inherit( Child, Parent )
	local Child = routines.utils.deepCopy( Child )
	local Parent = routines.utils.deepCopy( Parent )
	if Child ~= nil then
		setmetatable( Child, Parent )
		Child.__index = Child
	end
	--Child.ClassName = Child.ClassName .. '.' .. Child.ClassID
	self:T( 'Inherited from ' .. Parent.ClassName ) 
	return Child
end

--- This is the worker method to retrieve the Parent class.
-- @param BASE Child is the Child class from which the Parent class needs to be retrieved.
-- @return Parent
function BASE:Inherited( Child )
	local Parent = getmetatable( Child )
--	env.info('Inherited class of ' .. Child.ClassName .. ' is ' .. Parent.ClassName )
	return Parent
end

--- Get the ClassName + ClassID of the class instance.
-- The ClassName + ClassID is formatted as '%s#%09d'. 
-- @param #BASE self
-- @return #string The ClassName + ClassID of the class instance.
function BASE:GetClassNameAndID()
  return string.format( '%s#%09d', self:GetClassName(), self:GetClassID() )
end

--- Get the ClassName of the class instance.
-- @param #BASE self
-- @return #string The ClassName of the class instance.
function BASE:GetClassName()
  return self.ClassName
end

--- Get the ClassID of the class instance.
-- @param #BASE self
-- @return #string The ClassID of the class instance.
function BASE:GetClassID()
  return self.ClassID
end


function BASE:AddEvent( Event, EventFunction )
	self:F( Event )

	self.Events[#self.Events+1] = {}
	self.Events[#self.Events].Event = Event
	self.Events[#self.Events].EventFunction = EventFunction
	self.Events[#self.Events].EventEnabled = false

	return self
end


function BASE:EnableEvents()
	self:F( #self.Events )

	for EventID, Event in pairs( self.Events ) do
		Event.Self = self
		Event.EventEnabled = true
	end
	self.Events.Handler = world.addEventHandler( self )

	return self
end

function BASE:DisableEvents()
	self:F()
  
	world.removeEventHandler( self )
	for EventID, Event in pairs( self.Events ) do
		Event.Self = nil
		Event.EventEnabled = false
	end

	return self
end


local BaseEventCodes = {
   "S_EVENT_SHOT",
   "S_EVENT_HIT",
   "S_EVENT_TAKEOFF",
   "S_EVENT_LAND",
   "S_EVENT_CRASH",
   "S_EVENT_EJECTION",
   "S_EVENT_REFUELING",
   "S_EVENT_DEAD",
   "S_EVENT_PILOT_DEAD",
   "S_EVENT_BASE_CAPTURED",
   "S_EVENT_MISSION_START",
   "S_EVENT_MISSION_END",
   "S_EVENT_TOOK_CONTROL",
   "S_EVENT_REFUELING_STOP",
   "S_EVENT_BIRTH",
   "S_EVENT_HUMAN_FAILURE",
   "S_EVENT_ENGINE_STARTUP",
   "S_EVENT_ENGINE_SHUTDOWN",
   "S_EVENT_PLAYER_ENTER_UNIT",
   "S_EVENT_PLAYER_LEAVE_UNIT",
   "S_EVENT_PLAYER_COMMENT",
   "S_EVENT_SHOOTING_START",
   "S_EVENT_SHOOTING_END",
   "S_EVENT_MAX",
}
 
--onEvent( {[1]="S_EVENT_BIRTH",[2]={["subPlace"]=5,["time"]=0,["initiator"]={["id_"]=16884480,},["place"]={["id_"]=5000040,},["id"]=15,["IniUnitName"]="US F-15C@RAMP-Air Support Mountains#001-01",},}
-- Event = {
--   id = enum world.event,
--   time = Time,
--   initiator = Unit,
--   target = Unit,
--   place = Unit,
--   subPlace = enum world.BirthPlace,
--   weapon = Weapon
-- }


function BASE:CreateEventBirth( EventTime, Initiator, IniUnitName, place, subplace )
	self:F( { EventTime, Initiator, IniUnitName, place, subplace } )

	local Event = {
		id = world.event.S_EVENT_BIRTH,
		time = EventTime,
		initiator = Initiator,
		IniUnitName = IniUnitName,
		place = place,
		subplace = subplace
		}

	world.onEvent( Event )
end

function BASE:CreateEventCrash( EventTime, Initiator )
	self:F( { EventTime, Initiator } )

	local Event = {
		id = world.event.S_EVENT_CRASH,
		time = EventTime,
		initiator = Initiator,
		}

	world.onEvent( Event )
end
												
function BASE:onEvent(event)

	--env.info( 'onEvent Table self = ' .. tostring(self) )
	if self then
		for EventID, EventObject in pairs( self.Events ) do
			if EventObject.EventEnabled then
				--env.info( 'onEvent Table EventObject.Self = ' .. tostring(EventObject.Self) )
				--env.info( 'onEvent event.id = ' .. tostring(event.id) )
				--env.info( 'onEvent EventObject.Event = ' .. tostring(EventObject.Event) )
				if event.id == EventObject.Event then
					if self == EventObject.Self then
						if event.initiator and event.initiator:isExist() then
							event.IniUnitName = event.initiator:getName()
						end
						if event.target and event.target:isExist() then
							event.TgtUnitName = event.target:getName()
						end
						self:T( { BaseEventCodes[event.id], event } )
						EventObject.EventFunction( self, event )
					end
				end
			end
		end
	end

end

-- Trace section

-- Log a trace (only shown when trace is on)
-- TODO: Make trace function using variable parameters.

function BASE:F( Arguments )

  if _TraceOn and _TraceClass[self.ClassName] then

    local DebugInfoCurrent = debug.getinfo( 2, "nl" )
    local DebugInfoFrom = debug.getinfo( 3, "l" )
    
    local Function = "function"
    if DebugInfoCurrent.name then
      Function = DebugInfoCurrent.name
    end

    local LineCurrent = DebugInfoCurrent.currentline
    local LineFrom = 0
    if DebugInfoFrom then
      LineFrom = DebugInfoFrom.currentline
    end
    env.info( string.format( "%6d\(%6d\)/%1s:%20s%05d.%s\(%s\)" , LineCurrent, LineFrom, "F", self.ClassName, self.ClassID, Function, routines.utils.oneLineSerialize( Arguments ) ) )
  end
end

function BASE:F2( Arguments )

  if _TraceLevel >= 2 then
    self:F( Arguments )
  end
  
end

function BASE:F3( Arguments )

  if _TraceLevel >= 3 then
    self:F( Arguments )
  end
  
end

function BASE:T( Arguments )

	if _TraceOn and _TraceClass[self.ClassName] then

		local DebugInfoCurrent = debug.getinfo( 2, "nl" )
		local DebugInfoFrom = debug.getinfo( 3, "l" )
		
		local Function = "function"
		if DebugInfoCurrent.name then
			Function = DebugInfoCurrent.name
		end

		local LineCurrent = DebugInfoCurrent.currentline
		local LineFrom = 0
		if DebugInfoFrom then
		  LineFrom = DebugInfoFrom.currentline
	  end
		env.info( string.format( "%6d\(%6d\)/%1s:%20s%05d.%s" , LineCurrent, LineFrom, "T", self.ClassName, self.ClassID, routines.utils.oneLineSerialize( Arguments ) ) )
	end
end

function BASE:T2( Arguments )

  if _TraceLevel >= 2 then
    self:T( Arguments )
  end
  
end

function BASE:T3( Arguments )

  if _TraceLevel >= 3 then
    self:T( Arguments )
  end
  
end



-- Log an exception
function BASE:E( Arguments )

	local DebugInfoCurrent = debug.getinfo( 2, "nl" )
	local DebugInfoFrom = debug.getinfo( 3, "l" )
	
	local Function = "function"
	if DebugInfoCurrent.name then
		Function = DebugInfoCurrent.name
	end

	local LineCurrent = DebugInfoCurrent.currentline
	local LineFrom = DebugInfoFrom.currentline

	env.info( string.format( "%6d\(%6d\)/%1s:%20s%05d.%s\(%s\)" , LineCurrent, LineFrom, "E", self.ClassName, self.ClassID, Function, routines.utils.oneLineSerialize( Arguments ) ) )
end


