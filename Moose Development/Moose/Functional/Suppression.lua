-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- **Functional** - Suppress fire of ground units when they get hit.
-- 
-- ![Banner Image](..\Presentations\SUPPRESSION\SUPPRESSION.jpg)
-- 
-- ====
-- 
-- When ground units get hit by (suppressive) enemy fire, they will not be able to shoot back for a certain amount of time.
-- 
-- The implementation is based on an idea and script by MBot. See the [DCS forum threat](https://forums.eagle.ru/showthread.php?t=107635) for details.
-- 
-- In addition to suppressing the fire, conditions can be specified which let the group retreat to a defined zone, move away from the attacker
-- or hide at a nearby scenery object.
-- 
-- ====
-- 
-- # Demo Missions
--
-- ### [ALL Demo Missions pack of the last release](https://github.com/FlightControl-Master/MOOSE_MISSIONS/releases)
-- 
-- ====
-- 
-- # YouTube Channel
-- 
-- ### [MOOSE YouTube Channel](https://www.youtube.com/playlist?list=PL7ZUrU4zZUl1jirWIo4t4YxqN-HxjqRkL)
-- 
-- ===
-- 
-- ### Author: **[funkyfranky](https://forums.eagle.ru/member.php?u=115026)**
-- 
-- ### Contributions: **Sven van de Velde ([FlightControl](https://forums.eagle.ru/member.php?u=89536))**
-- 
-- ====
-- @module Suppression

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- SUPPRESSION class
-- @type SUPPRESSION
-- @field #string ClassName Name of the class.
-- @field #boolean debug Write debug messages to DCS log file and send debug messages to all players.
-- @field #boolean flare Flare units when they get hit or die.
-- @field #boolean smoke Smoke places to which the group retreats, falls back or hides.
-- @field #list DCSdesc Table containing all DCS descriptors of the group.
-- @field #string Type Type of the group.
-- @field #number SpeedMax Maximum speed of group in km/h.
-- @field #boolean IsInfantry True if group has attribute Infantry.
-- @field Core.Controllable#CONTROLLABLE Controllable Controllable of the FSM. Must be a ground group.
-- @field #number Tsuppress_ave Average time in seconds a group gets suppressed. Actual value is sampled randomly from a Gaussian distribution.
-- @field #number Tsuppress_min Minimum time in seconds the group gets suppressed.
-- @field #number Tsuppress_max Maximum time in seconds the group gets suppressed.
-- @field #number TsuppressionOver Time at which the suppression will be over.
-- @field #number IniGroupStrength Number of units in a group at start.
-- @field #number Nhit Number of times the group was hit.
-- @field #string Formation Formation which will be used when falling back, taking cover or retreating. Default "Vee".
-- @field #number Speed Speed the unit will use when falling back, taking cover or retreating. Default 999.
-- @field #boolean MenuON If true creates a entry in the F10 menu.
-- @field #boolean FallbackON If true, group can fall back, i.e. move away from the attacking unit.
-- @field #number FallbackWait Time in seconds the unit will wait at the fall back point before it resumes its mission.
-- @field #number FallbackDist Distance in meters the unit will fall back.
-- @field #number FallbackHeading Heading in degrees to which the group should fall back. Default is directly away from the attacking unit.
-- @field #boolean TakecoverON If true, group can hide at a nearby scenery object.
-- @field #number TakecoverWait Time in seconds the group will hide before it will resume its mission.
-- @field #number TakecoverRange Range in which the group will search for scenery objects to hide at.
-- @field Wrapper.Scenery#SCENERY hideout Scenery object where the group will try to take cover.
-- @field #number PminFlee Minimum probability in percent that a group will flee (fall back or take cover) at each hit event. Default is 10 %.
-- @field #number PmaxFlee Maximum probability in percent that a group will flee (fall back or take cover) at each hit event. Default is 90 %.
-- @field Core.Zone#ZONE RetreatZone Zone to which a group retreats.
-- @field #number RetreatDamage Damage in percent at which the group will be ordered to retreat.
-- @field #number RetreatWait Time in seconds the group will wait in the retreat zone before it resumes its mission. Default two hours. 
-- @field #string CurrentAlarmState Alam state the group is currently in.
-- @field #string CurrentROE ROE the group currently has.
-- @field #string DefaultAlarmState Alarm state the group will go to when it is changed back from another state. Default is "Auto".
-- @field #string DefaultROE ROE the group will get once suppression is over. Default is "Free".
-- @extends Core.Fsm#FSM_CONTROLLABLE
-- 

---# SUPPRESSION class, extends @{Core.Fsm#FSM_CONTROLLABLE}
-- Mimic suppressive enemy fire and let groups flee or retreat.
-- 
-- ## Suppression Process
-- 
-- ![Process](..\Presentations\SUPPRESSION\Suppression_Process.png)
-- 
-- The suppression process can be described as follows.
-- 
-- ### CombatReady
-- 
-- A group starts in the state **CombatReady**. In this state the group is ready to fight. The ROE is set to either "Weapon Free" or "Return Fire".
-- The alarm state is set to either "Auto" or "Red".
-- 
-- ### Event Hit
-- The most important event in this scenario is the **Hit** event. This is an event of the FSM and triggered by the DCS event hit.
-- 
-- ### Suppressed
-- After the **Hit** event the group changes its state to **Suppressed**. Technically, the ROE of the group is changed to "Weapon Hold".
-- The suppression of the group will last a certain amount of time. It is randomized an will vary each time the group is hit.
-- The expected suppression time is set to 15 seconds by default. But the actual value is sampled from a Gaussian distribution.
--  
-- ![Process](..\Presentations\SUPPRESSION\Suppression_Gaussian.png)
-- 
-- The graph shows the distribution of suppression times if a group would be hit 100,000 times. As can be seen, on most hits the group gets
-- suppressed for around 15 seconds. Other values are also possible but they become less likely the further away from the "expected" suppression time they are.
-- Minimal and maximal suppression times can also be specified. By default these are set to 5 and 25 seconds, respectively. This can also be seen in the graph
-- because the tails of the Gaussian distribution are cut off at these values.
-- 
-- ### Event Recovered
-- After the suppression time is over, the event **Recovered** is initiated and the group becomes **CombatReady** again.
-- The ROE of the group will be set to "Weapon Free".
-- 
-- Of course, it can also happen that a group is hit again while it is still suppressed. In that case a new random suppression time is calculated.
-- If the new suppression time is longer than the remaining suppression of the previous hit, then the group recovers when the suppression time of the last
-- hit has passed.
-- If the new suppression time is shorter than the remaining suppression, the group will recover after the longer time of the first suppression has passed
-- 
-- For example:
-- 
-- * A group gets hit the first time and is suppressed for - let's say - 15 seconds.
-- * After 10 seconds, i.e. when 5 seconds of the old suppression are left, the group gets hit a again.
-- * A new suppression time is calculated which can be smaller or larger than the remaining 5 seconds.
-- * If the new suppression time is smaller, e.g. three seconds, than five seconds, the group will recover after the 5 remaining seconds of the first suppression have passed.
-- * If the new suppression time is longer than last suppression time, e.g. 10 seconds, then the group will recover after the 10 seconds of the new hit have passed.
-- 
-- Generally speaking, the suppression times are not just added on top of each other. Because this could easily lead to the situation that a group 
-- never becomes CombatReady again before it gets destroyed.
-- 
-- ## Flee Events and States
-- Apart from being suppressed the groups can also flee from the enemy under certain conditions.
-- 
-- ### Event Retreat
-- The first option is a retreat. This can be enabled by setting a retreat zone, i.e. a trigger zone defined in the mission editor.
-- 
-- If the group takes a certain amount of damage, the event **Retreat** will be called and the group will start to move to the retreat zone.
-- The group will be in the state **Retreating**, which means that its ROE is set to "Weapon Hold" and the alarm state is set to "Green".
-- Setting the alarm state to green is necessary to enable the group to move under fire.
-- 
-- If no option retreat zone has been specified, the option retreat is not available.
-- 
-- ### Fallback
-- 
-- If a group is attacked by another ground group, it has the option to fall back, i.e. move away from the enemy. The probability of the event **FallBack** to
-- happen depends on the damage of the group that was hit. The more a group gets damaged, the more likely **FallBack** event becomes.
-- 
-- If the group enters the state **FallingBack** it will move 100 meters in the opposite direction of the attacking unit. ROE and alarmstate are set to "Weapon Hold"
-- and "Green", respectively.
-- 
-- At the fallback point the group will wait for 60 seconds before it resumes its normal mission.
-- 
-- ### TakeCover
-- 
-- If a group is hit by either another ground or air unit, it has the option to "take cover" or "hide". This means that the group will move to a random
-- scenery object in it vicinity.
-- 
-- Analogously to the fall back case, the probability of a **TakeCover** event to occur, depends on the damage of the group. The more a group is damaged, the more
-- likely it becomes that a group takes cover.
-- 
-- When a **TakeCover** event occurs an area with a radius of 300 meters around the hit group is searched for an arbitrary scenery object.
-- If at least one scenery object is found, the group will move there. One it has reached its "hideout", it will wait there for two minutes before it resumes its
-- normal mission.
-- 
-- If more than one scenery object is found, the group will move to a random one.
-- If no scenery object is near the group the **TakeCover** event is rejected and the group will not move.
-- 
-- # Examples
-- 
-- ![Process](..\Presentations\SUPPRESSION\Suppression_Example_01.png)
-- 
-- 
-- 
-- @field #SUPPRESSION
SUPPRESSION={
  ClassName = "SUPPRESSION",
  debug = true,
  flare = true,
  smoke = true,
  DCSdesc = nil,
  Type = nil,
  IsInfantry=nil,
  SpeedMax = nil,
  Tsuppress_ave = 15,
  Tsuppress_min = 5,
  Tsuppress_max = 25,
  TsuppressOver = nil,
  IniGroupStrength = nil,
  Nhit = 0,
  Formation = "Vee",
  Speed = 4,
  MenuON = true,
  FallbackON = false,
  FallbackWait = 60,
  FallbackDist = 100,
  FallbackHeading = nil,
  TakecoverON = true,
  TakecoverWait = 120,
  TakecoverRange = 300,
  hideout = nil,
  PminFlee = 10,
  PmaxFlee = 90,
  RetreatZone = nil,
  RetreatDamage = nil,
  RetreatWait = 7200,
  CurrentAlarmState = "unknown",
  CurrentROE = "unknown",
  DefaultAlarmState = "Auto",
  DefaultROE = "Weapon Free",
}

--- Enumerator of possible rules of engagement.
-- @field #list ROE
SUPPRESSION.ROE={
  Hold="Weapon Hold",
  Free="Weapon Free",
  Return="Return Fire",  
}

--- Enumerator of possible alarm states.
-- @field #list AlarmState
SUPPRESSION.AlarmState={
  Auto="Auto",
  Green="Green",
  Red="Red",
}

--- Main F10 menu for suppresion, i.e. F10/Suppression.
-- @field #string MenuF10
SUPPRESSION.MenuF10=nil

--- Some ID to identify who we are in output of the DCS.log file.
-- @field #string id
SUPPRESSION.id="SFX | "

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--TODO: Figure out who was shooting and move away from him.
--TODO: Move behind a scenery building if there is one nearby.
--TODO: Retreat to a given zone or point.

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Creates a new AI_suppression object.
-- @param #SUPPRESSION self
-- @param Wrapper.Group#GROUP group The GROUP object for which suppression should be applied.
-- @return #SUPPRESSION SUPPRESSION object.
-- @return nil If group does not exist or is not a ground group.
function SUPPRESSION:New(group)

  -- Check that group is present.
  if group then
    env.info(SUPPRESSION.id.."Suppressive fire for group "..group:GetName())
  else
    env.info(SUPPRESSION.id.."Suppressive fire: Requested group does not exist! (Has to be a MOOSE group.)")
    return nil
  end
  
  -- Check that we actually have a GROUND group.
  if group:IsGround()==false then
    env.error(SUPPRESSION.id.."SUPPRESSION fire group "..group:GetName().." has to be a GROUND group!")
    return nil
  end

  -- Inherits from FSM_CONTROLLABLE
  local self=BASE:Inherit(self, FSM_CONTROLLABLE:New()) -- #SUPPRESSION
  
  -- Set the controllable for the FSM.
  self:SetControllable(group)
  
  -- Get DCS descriptors of group.
  local DCSgroup=Group.getByName(group:GetName())
  local DCSunit=DCSgroup:getUnit(1)
  self.DCSdesc=DCSunit:getDesc()
  
  -- Get max speed the group can do and convert to km/h.
  self.SpeedMax=self.DCSdesc.speedMaxOffRoad*3.6
  --self.SpeedMaxOffRoad=DCSdesc.speedMaxOffRoad
  
  -- Set speed to maximum.
  self.Speed=self.SpeedMax
  
  -- Is this infantry or not.
  self.IsInfantry=DCSunit:hasAttribute("Infantry")
  
  -- Type of group.
  self.Type=group:GetTypeName()
  
  -- Initial group strength.
  self.IniGroupStrength=#group:GetUnits()
  
  -- Set ROE and Alarm State.
  self:SetDefaultROE("Free")
  self:SetDefaultAlarmState("Auto")
  
  -- Transitions 
  self:AddTransition("*",           "Start",     "CombatReady")
  self:AddTransition("CombatReady", "Hit",       "Suppressed")
  self:AddTransition("Suppressed",  "Hit",       "Suppressed") 
  self:AddTransition("Suppressed",  "Recovered", "CombatReady")
  self:AddTransition("Suppressed",  "TakeCover", "TakingCover")
  self:AddTransition("Suppressed",  "FallBack",  "FallingBack")
  self:AddTransition("Suppressed",  "Retreat",   "Retreating")
  self:AddTransition("TakingCover", "FightBack", "CombatReady")
  self:AddTransition("FallingBack", "FightBack", "CombatReady")  
  self:AddTransition("*",           "Dead",      "*")
  
  return self
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Set average, minimum and maximum time a unit is suppressed each time it gets hit.
-- @param #SUPPRESSION self
-- @param #number Tave Average time [seconds] a group will be suppressed. Default is 15 seconds.
-- @param #number Tmin (Optional) Minimum time [seconds] a group will be suppressed. Default is 5 seconds.
-- @param #number Tmax (Optional) Maximum time a group will be suppressed. Default is 25 seconds.
function SUPPRESSION:SetSuppressionTime(Tave, Tmin, Tmax)

  -- Minimum suppression time is input or default but at least 1 second.
  self.Tsuppress_min=Tmin or self.Tsuppress_min
  self.Tsuppress_min=math.max(self.Tsuppress_min, 1)
  
  -- Maximum suppression time is input or dault but at least Tmin.
  self.Tsuppress_max=Tmax or self.Tsuppress_max
  self.Tsuppress_max=math.max(self.Tsuppress_max, self.Tsuppress_min)
  
  -- Expected suppression time is input or default but at leat Tmin and at most Tmax.
  self.Tsuppress_ave=Tave or self.Tsuppress_ave
  self.Tsuppress_ave=math.max(self.Tsuppress_min)
  self.Tsuppress_ave=math.min(self.Tsuppress_max)
  
  if self.debug then
    env.info(SUPPRESSION.id..string.format("Set ave suppression time to %d seconds.", self.Tsuppress_ave))
    env.info(SUPPRESSION.id..string.format("Set min suppression time to %d seconds.", self.Tsuppress_min))
    env.info(SUPPRESSION.id..string.format("Set max suppression time to %d seconds.", self.Tsuppress_max))
  end
end

--- Set the zone to which a group retreats after being damaged too much.
-- @param #SUPPRESSION self
-- @param Core.Zone#ZONE zone MOOSE zone object.
function SUPPRESSION:SetRetreatZone(zone)
  self.RetreatZone=zone
end

--- Turn debug mode on. Enables messages and more output to DCS log file.
-- @param #SUPPRESSION self
function SUPPRESSION:DebugOn()
  self.debug=true
end

--- Flare units when they are hit, die or recover from suppression.
-- @param #SUPPRESSION self
function SUPPRESSION:FlareOn()
  self.flare=true
end

--- Smoke positions where units fall back to, hide or retreat.
-- @param #SUPPRESSION self
function SUPPRESSION:SmokeOn()
  self.smoke=true
end

--- Set the formation a group uses for fall back, hide or retreat.
-- @param #SUPPRESSION self
-- @param #string formation Formation of the group. Default "Vee".
function SUPPRESSION:SetFormation(formation)
  self.Formation=formation or "Vee"
end

--- Set speed a group moves at for fall back, hide or retreat.
-- @param #SUPPRESSION self
-- @param #number speed Speed in km/h of group. Default max speed the group can do.
function SUPPRESSION:SetSpeed(speed)
  self.Speed=speed or self.SpeedMax
  self.Speed=math.min(self.Speed, self.SpeedMax)
end

--- Enable fall back if a group is hit.
-- @param #SUPPRESSION self
-- @param #boolean switch Enable=true or disable=false fall back of group.
function SUPPRESSION:Fallback(switch)
  if switch==nil then
    switch=true
  end
  self.FallbackON=switch
end

--- Set distance a group will fall back when it gets hit.
-- @param #SUPPRESSION self
-- @param #number distance Distance in meters.
function SUPPRESSION:SetFallbackDistance(distance)
  self.FallbackDist=distance
end

--- Set time a group waits at its fall back position before it resumes its normal mission.
-- @param #SUPPRESSION self
-- @param #number time Time in seconds.
function SUPPRESSION:SetFallbackWait(time)
  self.FallbackWait=time
end

--- Enable take cover option if a unit is hit.
-- @param #SUPPRESSION self
-- @param #boolean switch Enable=true or disable=false fall back of group.
function SUPPRESSION:Takecover(switch)
  if switch==nil then
    switch=true
  end
  self.TakecoverON=switch
end

--- Set time a group waits at its hideout position before it resumes its normal mission.
-- @param #SUPPRESSION self
-- @param #number time Time in seconds.
function SUPPRESSION:SetTakecoverWait(time)
  self.TakecoverWait=time
end

--- Set distance a group searches for hideout places.
-- @param #SUPPRESSION self
-- @param #number range Search range in meters.
function SUPPRESSION:SetTakecoverRange(range)
  self.TakecoverRange=range
end

--- Set hideout place explicitly.
-- @param #SUPPRESSION self
-- @param Wrapper.Scenery#SCENERY Hideout Place where the group will hide after the TakeCover event.
function SUPPRESSION:SetTakecoverRange(Hideout)
  self.hideout=Hideout
end

--- Set minimum probability that a group flees (falls back or takes cover) after a hit event. Default is 10%.
-- @param #SUPPRESSION self
-- @param #number probability Probability in percent.
function SUPPRESSION:SetMinimumFleeProbability(probability)
  self.PminFlee=probability or 10
end

--- Set maximum probability that a group flees (falls back or takes cover) after a hit event. Default is 90%.
-- @param #SUPPRESSION self
-- @param #number probability Probability in percent.
function SUPPRESSION:SetMinimumFleeProbability(probability)
  self.PmaxFlee=probability or 90
end

--- Set damage threshold before a group is ordered to retreat if a retreat zone was defined.
-- If the group consists of only a singe unit, this referrs to the life of the unit.
-- If the group consists of more than one unit, this referrs to the group strength relative to its initial strength.
-- @param #SUPPRESSION self
-- @param #number damage Damage in percent. If group gets damaged above this value, the group will retreat. Default 50 %.
function SUPPRESSION:SetRetreatDamage(damage)
  self.RetreatDamage=damage
end

--- Set time a group waits in the retreat zone before it resumes its mission. Default is two hours.
-- @param #SUPPRESSION self
-- @param #number time Time in seconds. Default 7200 seconds.
function SUPPRESSION:SetRetreatWait(time)
  self.RetreatWait=time
end

--- Set alarm state a group will get after it returns from a fall back or take cover.
-- @param #SUPPRESSION self
-- @param #string alarmstate Alarm state. Possible "Auto", "Green", "Red". Default is "Auto".
function SUPPRESSION:SetDefaultAlarmState(alarmstate)
  if alarmstate:lower()=="auto" then
    self.DefaultAlarmState=SUPPRESSION.AlarmState.Auto
  elseif alarmstate:lower()=="green" then
    self.DefaultAlarmState=SUPPRESSION.AlarmState.Green
  elseif alarmstate:lower()=="red" then
    self.DefaultAlarmState=SUPPRESSION.AlarmState.Red
  else
    self.DefaultAlarmState=SUPPRESSION.AlarmState.Auto
  end
end

--- Set Rules of Engagement (ROE) a group will get when it recovers from suppression.
-- @param #SUPPRESSION self
-- @param #string roe ROE after suppression. Possible "Free", "Hold" or "Return". Default "Free".
function SUPPRESSION:SetDefaultROE(roe)
  if roe:lower()=="free" then
    self.DefaultROE=SUPPRESSION.ROE.Free
  elseif roe:lower()=="hold" then
    self.DefaultROE=SUPPRESSION.ROE.Hold
  elseif roe:lower()=="return" then
    self.DefaultROE=SUPPRESSION.ROE.Return
  else
    self.DefaultROE=SUPPRESSION.ROE.Free
  end
end

--- Create an F10 menu entry for the suppressed group. The menu is mainly for debugging purposes.
-- @param #SUPPRESSION self
-- @param #boolean switch Enable=true or disable=false menu group. Default is true.
function SUPPRESSION:MenuOn(switch)
  if switch==nil then
    switch=true
  end
  self.MenuON=switch
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Create F10 main menu, i.e. F10/Suppression. The menu is mainly for debugging purposes.
-- @param #SUPPRESSION self
function SUPPRESSION:_CreateMenuGroup()
  local SubMenuName=self.Controllable:GetName()
  local MenuGroup=MENU_MISSION:New(SubMenuName, SUPPRESSION.MenuF10)
  MENU_MISSION_COMMAND:New("Fallback!", MenuGroup, self.OrderFallBack, self)
  MENU_MISSION_COMMAND:New("Take Cover!", MenuGroup, self.OrderTakeCover, self)
  MENU_MISSION_COMMAND:New("Retreat!", MenuGroup, self.OrderRetreat, self)
  MENU_MISSION_COMMAND:New("Report Status", MenuGroup, self.Status, self, true)
end

--- Order group to fall back between 100 and 150 meters in a random direction.
-- @param #SUPPRESSION self
function SUPPRESSION:OrderFallBack()
  local group=self.Controllable --Wrapper.Controllable#CONTROLLABLE
  local vicinity=group:GetCoordinate():GetRandomVec2InRadius(150, 100)
  local coord=COORDINATE:NewFromVec2(vicinity)
  self:FallBack(self.Controllable)
end

--- Order group to take cover at a nearby scenery object.
-- @param #SUPPRESSION self
function SUPPRESSION:OrderTakeCover()
  self:TakeCover()
end

--- Order group to retreat to a pre-defined zone.
-- @param #SUPPRESSION self
function SUPPRESSION:OrderRetreat()
  self:Retreat()
end

--- Status of group. Current ROE, alarm state, life.
-- @param #SUPPRESSION self
-- @param #boolean message Send message to all players.
function SUPPRESSION:Status(message)

  local name=self.Controllable:GetName()
  local nunits=#self.Controllable:GetUnits()
  local roe=self.CurrentROE
  local state=self.CurrentAlarmState
  local life_min, life_max, life_ave, life_ave0, groupstrength=self:_GetLife()
  
  local text=string.format("Status of group %s\n", name)
  text=text..string.format("Number of units: %d of %d\n", nunits, self.IniGroupStrength)
  text=text..string.format("Current state: %s\n", self:GetState())
  text=text..string.format("ROE: %s\n", roe)  
  text=text..string.format("Alarm state: %s\n", state)
  text=text..string.format("Hits taken: %d\n", self.Nhit)
  text=text..string.format("Life min: %3.0f\n", life_min)
  text=text..string.format("Life max: %3.0f\n", life_max)
  text=text..string.format("Life ave: %3.0f\n", life_ave)
  text=text..string.format("Life ave0: %3.0f\n", life_ave0)
  text=text..string.format("Group strength: %3.0f", groupstrength)
  
  MESSAGE:New(text, 10):ToAllIf(message or self.debug)
  env.info(SUPPRESSION.id..text)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- After "Start" event. Initialized ROE and alarm state. Starts the event handler.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function SUPPRESSION:onafterStart(Controllable, From, Event, To)
  self:_EventFromTo("onafterStart", Event, From, To)
  
  local text=string.format("Started SUPPRESSION for group %s.", Controllable:GetName())
  MESSAGE:New(text, 10):ToAllIf(self.debug)
  
  local rzone="not defined"
  if self.RetreatZone then
    rzone=self.RetreatZone:GetName()
  end
  
  -- Set retreat damage value if it was not set by user input.
  if self.RetreatDamage==nil then
    if self.RetreatZone then
      if self.IniGroupStrength==1 then
        self.RetreatDamage=60.0  -- 40% of life is left.
      elseif self.IniGroupStrength==2 then
        self.RetreatDamage=50.0  -- 50% of group left, i.e. 1 of 2. We already order a retreat, because if for a group 2 two a zone is defined it would not be used at all.
      else
        self.RetreatDamage=66.5  -- 34% of the group is left, e.g. 1 of 3,4 or 5, 2 of 6,7 or 8, 3 of 9,10 or 11, 4/12, 4/13, 4/14, 5/15, ... 
      end
    else
      self.RetreatDamage=100   -- If no retreat then this should be set to 100%.
    end
  end
  
  -- Create main F10 menu if it is not there yet.
  if self.MenuON then 
    if not SUPPRESSION.MenuF10 then
      SUPPRESSION.MenuF10 = MENU_MISSION:New("Suppression")
    end
    self:_CreateMenuGroup()
  end
    
  -- Set the current ROE and alam state.
  self:_SetAlarmState(self.DefaultAlarmState)
  self:_SetROE(self.DefaultROE)
  
  local text=string.format("\n******************************************************\n")
  text=text..string.format("Suppressed group   = %s\n", Controllable:GetName())
  text=text..string.format("Type               = %s\n", self.Type)
  text=text..string.format("IsInfantry         = %s\n", tostring(self.IsInfantry))  
  text=text..string.format("Group strength     = %d\n", self.IniGroupStrength)
  text=text..string.format("Average time       = %5.1f seconds\n", self.Tsuppress_ave)
  text=text..string.format("Minimum time       = %5.1f seconds\n", self.Tsuppress_min)
  text=text..string.format("Maximum time       = %5.1f seconds\n", self.Tsuppress_max)
  text=text..string.format("Default ROE        = %s\n", self.DefaultROE)
  text=text..string.format("Default AlarmState = %s\n", self.DefaultAlarmState)
  text=text..string.format("Fall back ON       = %s\n", tostring(self.FallbackON))
  text=text..string.format("Fall back distance = %5.1f m\n", self.FallbackDist)
  text=text..string.format("Fall back wait     = %5.1f seconds\n", self.FallbackWait)
  text=text..string.format("Fall back heading  = %s degrees\n", tostring(self.FallbackHeading))
  text=text..string.format("Take cover ON      = %s\n", tostring(self.TakecoverON))
  text=text..string.format("Take cover search  = %5.1f m\n", self.TakecoverRange)
  text=text..string.format("Take cover wait    = %5.1f seconds\n", self.TakecoverWait)  
  text=text..string.format("Min flee probability = %5.1f\n", self.PminFlee)  
  text=text..string.format("Max flee probability = %5.1f\n", self.PmaxFlee)
  text=text..string.format("Retreat zone       = %s\n", rzone)
  text=text..string.format("Retreat damage     = %5.1f %%\n", self.RetreatDamage)
  text=text..string.format("Retreat wait       = %5.1f seconds\n", self.RetreatWait)
  text=text..string.format("Speed              = %5.1f km/h\n", self.Speed)
  text=text..string.format("Speed max          = %5.1f km/h\n", self.SpeedMax)
  text=text..string.format("Formation          = %s\n", self.Formation)
  text=text..string.format("******************************************************\n")
  env.info(SUPPRESSION.id..text)
    
  -- Add event handler.
  world.addEventHandler(self)
  self:HandleEvent(EVENTS.Dead, self._OnEventDead)
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Before "Hit" event. (Of course, this is not really before the group got hit.)
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
-- @param Wrapper.Unit#UNIT Unit Unit that was hit.
-- @param Wrapper.Unit#UNIT AttackUnit Unit that attacked.
function SUPPRESSION:onbeforeHit(Controllable, From, Event, To, Unit, AttackUnit)
  self:_EventFromTo("onbeforeHit", Event, From, To)
  
  --local Tnow=timer.getTime()
  --env.info(SUPPRESSION.id..string.format("Last hit = %s  %s", tostring(self.LastHit), tostring(Tnow)))
  
  return true
  --[[
  if self.LastHit==nil then
  
    -- First time group was hit
    self.LastHit=Tnow
    return true
    
  else
  
    -- Allow next hit only after a certain time has passed
    if Tnow-self.LastHit < 3 then
      return false
    else
      self.LastHit=Tnow
      return true
    end
    
  end
  ]]
end

--- After "Hit" event.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
-- @param Wrapper.Unit#UNIT Unit Unit that was hit.
-- @param Wrapper.Unit#UNIT AttackUnit Unit that attacked.
function SUPPRESSION:onafterHit(Controllable, From, Event, To, Unit, AttackUnit)
  self:_EventFromTo("onafterHit", Event, From, To)
    
  -- Suppress unit.
  if From=="CombatReady" or From=="Suppressed" then
    self:_Suppress()
  end
  
  -- Get life of group in %.
  local life_min, life_max, life_ave, life_ave0, groupstrength=self:_GetLife()
  
  -- Damage in %. If group consists only of one unit, we take its life value.
  local Damage=100-life_ave0
  
  -- Condition for retreat.
  local RetreatCondition = Damage >= self.RetreatDamage-0.01 and self.RetreatZone
    
  -- Probability that a unit flees. The probability increases linearly with the damage of the group/unit.
  -- If Damage=0             ==> P=Pmin
  -- if Damage=RetreatDamage ==> P=Pmax
  -- If no retreat zone has been specified, RetreatDamage is 100.
  local Pflee=(self.PmaxFlee-self.PminFlee)/self.RetreatDamage * math.min(Damage, self.RetreatDamage) + self.PminFlee
  
  -- Evaluate flee condition.
  local P=math.random(0,100)
  local FleeCondition =  P < Pflee
  
  local text
  text=string.format("Group %s: Life min=%5.1f, max=%5.1f, ave=%5.1f, ave0=%5.1f group=%5.1f", Controllable:GetName(), life_min, life_max, life_ave, life_ave0, groupstrength)
  env.info(SUPPRESSION.id..text)
  text=string.format("Group %s: Damage = %8.4f (%8.4f retreat threshold).", Controllable:GetName(), Damage, self.RetreatDamage)
  env.info(SUPPRESSION.id..text)
  text=string.format("Group %s: P_Flee = %5.1f %5.1f=P_rand (P_Flee > Prand ==> Flee)", Controllable:GetName(), Pflee, P)
  env.info(SUPPRESSION.id..text)
  
  -- Group is obviously destroyed.
  if Damage >= 99.9 then
    return
  end
  
  if RetreatCondition then
  
    -- Trigger Retreat event.
    self:Retreat()
    
  elseif FleeCondition then
  
    if self.FallbackON and AttackUnit:IsGround() then
    
      -- Trigger FallBack event.
      self:FallBack(AttackUnit)
      
    elseif self.TakecoverON then
    
      -- Search place to hide or take specified one.
      local Hideout=self.hideout
      if self.hideout==nil then
        Hideout=self:_SearchHideout()
      end
      
      -- Trigger TakeCover event.
      self:TakeCover(Hideout)
    end
  end
  
  -- Give info on current status.
  if self.debug then
    self:Status()
  end
  
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Before "Recovered" event. Check if suppression time is over.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function SUPPRESSION:onbeforeRecovered(Controllable, From, Event, To)
  self:_EventFromTo("onbeforeRecovered", Event, From, To)
  
  -- Current time.
  local Tnow=timer.getTime()
  
  -- Debug info
  if self.debug then
    env.info(SUPPRESSION.id..string.format("onbeforeRecovered: Time now: %d  - Time over: %d", Tnow, self.TsuppressionOver))
  end
  
  -- Recovery is only possible if enough time since the last hit has passed.
  if Tnow >= self.TsuppressionOver then
    return true
  else
    return false
  end
  
end

--- After "Recovered" event. Group has recovered and its ROE is set back to the "normal" unsuppressed state. Optionally the group is flared green.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function SUPPRESSION:onafterRecovered(Controllable, From, Event, To)
  self:_EventFromTo("onafterRecovered", Event, From, To)
  
  if Controllable and Controllable:IsAlive() then
  
    -- Debug message.
    local text=string.format("Group %s has recovered!", Controllable:GetName())
    MESSAGE:New(text, 10):ToAllIf(self.debug)
    env.info(SUPPRESSION.id..text)
    
    -- Set ROE back to default.
    self:_SetROE()
    
    -- Flare unit green.
    if self.flare or self.debug then
      Controllable:FlareGreen()
    end
    
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- After "FightBack" event. ROE and Alarm state are set back to default.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function SUPPRESSION:onafterFightBack(Controllable, From, Event, To)
  self:_EventFromTo("onafterFightBack", Event, From, To)
  
  -- Set ROE and alarm state back to default.
  self:_SetROE()
  self:_SetAlarmState()
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Before "FallBack" event. We check that group is not already falling back.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
-- @param Wrapper.Unit#UNIT AttackUnit Attacking unit. We will move away from this.
function SUPPRESSION:onbeforeFallBack(Controllable, From, Event, To, AttackUnit)
  self:_EventFromTo("onbeforeFallBack", Event, From, To)
  
  --TODO: Add retreat?
  if From == "FallingBack" then
    return false
  else
    return true
  end
end

--- After "FallBack" event. We get the heading away from the attacker and route the group a certain distance in that direction.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
-- @param Wrapper.Unit#UNIT AttackUnit Attacking unit. We will move away from this.
function SUPPRESSION:onafterFallBack(Controllable, From, Event, To, AttackUnit)
  self:_EventFromTo("onafterFallback", Event, From, To)
  
  if self.debug then
    env.info(SUPPRESSION.id..string.format("Group %s is falling back after %d hits.", Controllable:GetName(), self.Nhit))
  end
  
  -- Coordinate of the attacker and attacked unit.
  local ACoord=AttackUnit:GetCoordinate()
  local DCoord=Controllable:GetCoordinate()
  
  -- Heading from attacker to attacked unit.
  local heading=self:_Heading(ACoord, DCoord)
  
  -- Overwrite heading with user specified heading.
  if self.FallbackHeading then
    heading=self.FallbackHeading
  end
  
  -- Create a coordinate ~ 100 m in opposite direction of the attacking unit.
  local Coord=DCoord:Translate(self.FallbackDist, heading)
  
  -- Place marker
  local MarkerID=Coord:MarkToAll("Fall back position for group "..Controllable:GetName())
  
  -- Smoke the coordinate.
  if self.smoke or self.debug then
    Coord:SmokeBlue()
  end
  
  -- Set ROE to weapon hold.
  self:_SetROE(SUPPRESSION.ROE.Hold)
  
  -- Set alarm state to GREEN and let the unit run away.
  self:_SetAlarmState(SUPPRESSION.AlarmState.Green)

  -- Make the group run away.
  self:_Run(Coord, self.Speed, self.Formation, self.FallbackWait)
  
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Before "TakeCover" event. Search an area around the group for possible scenery objects where the group can hide.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
-- @param Wrapper.Scenery#SCENERY Hideout Place where the group will hide.
function SUPPRESSION:onbeforeTakeCover(Controllable, From, Event, To, Hideout)
  self:_EventFromTo("onbeforeTakeCover", Event, From, To)
  
  --TODO: Need to test this!
  if From=="TakingCover" then
    return false
  end
  
  -- Block transition if no hideout place is given.
  if Hideout ~= nil then
    return true
  else
    return false
  end

end

--- After "TakeCover" event. Group will run to a nearby scenery object and "hide" there for a certain time.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
-- @param Wrapper.Scenery#SCENERY Hideout Place where the group will hide.
function SUPPRESSION:onafterTakeCover(Controllable, From, Event, To, Hideout)
  self:_EventFromTo("onafterTakeCover", Event, From, To)
      
  local Coord=Hideout:GetCoordinate()
  
  if self.debug then
    local MarkerID=Coord:MarkToAll(string.format("Hideout place (%s) for group %s", Hideout:GetTypeName(), Controllable:GetName()))
    local text=string.format("Group %s is taking cover at %s!", Controllable:GetName(), Hideout:GetTypeName())
    MESSAGE:New(text, 10):ToAll()
    env.info(SUPPRESSION.id..text)
  end
  
  -- Smoke place of hideout.
  if self.smoke or self.debug then
    Coord:SmokeBlue()
  end
  
  -- Set ROE to weapon hold.
  self:_SetROE(SUPPRESSION.ROE.Hold)
  
  -- Set the ALARM STATE to GREEN. Then the unit will move even if it is under fire.
  self:_SetAlarmState(SUPPRESSION.AlarmState.Green)
  
  -- Make the group run away.
  self:_Run(Coord, self.Speed, self.Formation, self.TakecoverWait)
    
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Before "Retreat" event. We check that the group is not already retreating.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function SUPPRESSION:onbeforeRetreat(Controllable, From, Event, To)
  self:_EventFromTo("onbeforeRetreat", Event, From, To)
  
  if From=="Retreating" then
    if self.debug then
      local text=string.format("Group %s is already retreating.")
      env.info(SUPPRESSION.id..text)
    end
    return false
  else
    return true
  end
  
end

--- After "Retreat" event. Find a random point in the retreat zone and route the group there.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function SUPPRESSION:onafterRetreat(Controllable, From, Event, To)
  self:_EventFromTo("onafterRetreat", Event, From, To)
  
  -- Route the group to a zone.
  local text=string.format("Group %s is retreating! Alarm state green.", Controllable:GetName())
  MESSAGE:New(text, 10):ToAllIf(self.debug)
  env.info(SUPPRESSION.id..text)
  
  -- Get a random point in the retreat zone.
  local ZoneCoord=self.RetreatZone:GetRandomCoordinate() -- Core.Point#COORDINATE
  local ZoneVec2=ZoneCoord:GetVec2()

  -- Debug smoke zone and point.
  if self.smoke or self.debug then
    ZoneCoord:SmokeBlue()
  end
  if self.debug then
    self.RetreatZone:SmokeZone(SMOKECOLOR.Red, 12)
  end
  
  -- Set ROE to weapon hold.
  self:_SetROE(SUPPRESSION.ROE.Hold)
  
  -- Set the ALARM STATE to GREEN. Then the unit will move even if it is under fire.
  self:_SetAlarmState(SUPPRESSION.AlarmState.Green)
  
  -- Make unit run to retreat zone and wait there for ~two hours.
  self:_Run(ZoneCoord, self.Speed, self.Formation, self.RetreatWait)
  
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- After "Dead" event, when a unit has died. When all units of a group are dead, FSM is stopped and eventhandler removed.
-- @param #SUPPRESSION self
-- @param Wrapper.Controllable#CONTROLLABLE Controllable Controllable of the group.
-- @param #string From From state.
-- @param #string Event Event.
-- @param #string To To state.
function SUPPRESSION:onafterDead(Controllable, From, Event, To)
  self:_EventFromTo("onafterDead", Event, From, To)
  
  -- Number of units left in the group.
  local nunits=#self.Controllable:GetUnits()
      
  local text=string.format("Group %s: One of our units just died! %d units left.", self.Controllable:GetName(), nunits)
  MESSAGE:New(text, 10):ToAllIf(self.debug)
  env.info(SUPPRESSION.id..text)
      
  -- Go to stop state.
  if nunits==0 then
    env.info(string.format("Stopping SUPPRESSION for group %s.", Controllable:GetName()))
    self:Stop()
    self:UnHandleEvent(EVENTS.Dead)
    world.removeEventHandler(self)
  end
  
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--- Event Handler
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Event handler for suppressed groups.
--@param #SUPPRESSION self
function SUPPRESSION:onEvent(event)
  --self:E(event)
  
  local Tnow=timer.getTime()
  
  local name=self.Controllable:GetName()
  local ini = event.initiator
  local tgt = event.target


  -- INITIATOR
  local IniUnit=nil        -- Wrapper.Unit#UNIT
  local IniGroup=nil       -- Wrapper.Group#GROUP
  local IniUnitName=nil
  local IniGroupName=nil
  local IniGroupNameDCS=nil  
  if ini ~= nil then
    IniUnitName = ini:getName()
    IniGroupNameDCS=ini:getGroup():getName()
    -- TODO: For event Dead this sometimes (not always) gave nill! Don't know why. So I (re-)introduced the self:_OnEventDead function.
    IniUnit=UNIT:FindByName(IniUnitName)
    if IniUnit then
      IniGroup=IniUnit:GetGroup()
      IniGroupName=IniGroup:GetName()
    end
  end
  
  
  -- TARGET
  local TgtUnit=nil        -- Wrapper.Unit#UNIT
  local TgtGroup=nil       -- Wrapper.Group#GROUP
  local TgtUnitName=nil
  local TgtGroupName=nil
  local TgtGroupNameDCS=nil  
  if tgt ~= nil then
    TgtUnitName = tgt:getName()
    TgtGroupNameDCS=tgt:getGroup():getName()
    TgtUnit=UNIT:FindByName(TgtUnitName)
    if TgtUnit then
      TgtGroup=TgtUnit:GetGroup()
      TgtGroupName=TgtGroup:GetName()
    end
  end    
  
  
  -- Event HIT
  if event.id == world.event.S_EVENT_HIT then
  
    if TgtGroupName == name then
    
      env.info(SUPPRESSION.id..string.format("Hit event at t = %5.1f", Tnow))
    
      -- Flare unit that was hit.
      if self.flare or self.debug then
        TgtUnit:FlareRed()
      end
      
      -- Increase Hit counter.
      self.Nhit=self.Nhit+1
  
      -- Info on hit times.
      env.info(SUPPRESSION.id..string.format("Group %s has just been hit %d times.", self.Controllable:GetName(), self.Nhit))
      
      --self:Status()
      local life=tgt:getLife()/(tgt:getLife0()+1)*100
      env.info(SUPPRESSION.id..string.format("Target unit life = %5.1f", life))
    
      -- FSM Hit event.
      self:__Hit(3, TgtUnit, IniUnit)
    end
    
  end
  
end

--- Event handler for Dead event of suppressed groups.
--@param #SUPPRESSION self
function SUPPRESSION:_OnEventDead(Event)

  local GroupNameSelf=self.Controllable:GetName()
  local GroupNameIni=Event.IniGroupName

  if  GroupNameIni== GroupNameSelf then
    
    -- Dead Unit.
    local IniUnit=Event.IniUnit --Wrapper.Unit#UNIT
    local IniUnitName=Event.IniUnitName
    
    if not IniUnit then
      env.error(SUPPRESSION.id..string.format("Group %s: Dead unit does not exist! Unit name %s.", GroupNameIni, IniUnitName))
    end
    
    -- Flare unit that died.
    if self.flare or self.debug then
      IniUnit:FlareWhite()
    end
    
    -- Get status.
    self:Status()
    
    -- FSM Dead event.
    self:__Dead(0.1)
    
  end

end


-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

--- Suppress fire of a unit by setting its ROE to "Weapon Hold".
-- @param #SUPPRESSION self
function SUPPRESSION:_Suppress()

  -- Current time.
  local Tnow=timer.getTime()
  
  -- Controllable
  local Controllable=self.Controllable --Wrapper.Controllable#CONTROLLABLE
  
  -- Group will hold their weapons.
  self:_SetROE(SUPPRESSION.ROE.Hold)
  
  -- Get randomized time the unit is suppressed.
  local sigma=(self.Tsuppress_max-self.Tsuppress_min)/4
  local Tsuppress=self:_Random_Gaussian(self.Tsuppress_ave,sigma,self.Tsuppress_min, self.Tsuppress_max)
  
  -- Time at which the suppression is over.
  local renew=true
  if self.TsuppressionOver ~= nil then
    if Tsuppress+Tnow > self.TsuppressionOver then
      self.TsuppressionOver=Tnow+Tsuppress
    else
      renew=false
    end
  else
    self.TsuppressionOver=Tnow+Tsuppress
  end
  
  -- Recovery event will be called in Tsuppress seconds.
  if renew then
    self:__Recovered(self.TsuppressionOver-Tnow)
  end
  
  -- Debug message.
  local text=string.format("Group %s is suppressed for %d seconds. Suppression ends at %d:%02d.", Controllable:GetName(), Tsuppress, self.TsuppressionOver/60, self.TsuppressionOver%60)
  MESSAGE:New(text, 10):ToAllIf(self.debug)
  env.info(SUPPRESSION.id..text)

end


--- Make group run/drive to a certain point. We put in several intermediate waypoints because sometimes the group stops before it arrived at the desired point.
--@param #SUPPRESSION self
--@param Core.Point#COORDINATE fin Coordinate where we want to go.
--@param #number speed Speed of group. Default is 999.
--@param #string formation Formation of group. Default is "Vee".
--@param #number wait Time the group will wait/hold at final waypoint. Default is 30 seconds.
function SUPPRESSION:_Run(fin, speed, formation, wait)

  speed=speed or 999
  formation=formation or "Vee"
  wait=wait or 30

  local group=self.Controllable -- Wrapper.Controllable#CONTROLLABLE
  
  -- Clear all tasks.
  group:ClearTasks()
  
  -- Current coordinates of group.
  local ini=group:GetCoordinate()
  
  -- Distance between current and final point. 
  local dist=ini:Get2DDistance(fin)
  
  -- Heading from ini to fin.
  local heading=self:_Heading(ini, fin)
  
  -- Number of waypoints.
  local nx
  if dist <= 50 then
    nx=2
  elseif dist <= 100 then
    nx=3
  elseif dist <= 500 then
    nx=4
  else
    nx=5
  end
  
  -- Number of intermediate waypoints.
  local dx=dist/(nx-1)
    
  -- Waypoint and task arrays.
  local wp={}
  local tasks={}
  
  -- First waypoint is the current position of the group.
  wp[1]=ini:WaypointGround(speed, formation)
  local MarkerID=ini:MarkToAll(string.format("Waypoing %d of group %s (initial)", #wp, self.Controllable:GetName()))
  tasks[1]=group:TaskFunction("SUPPRESSION._Passing_Waypoint", self, 1, false)
  
  env.info(SUPPRESSION.id..string.format("Number of waypoints %d", nx))
  for i=1,nx-2 do
  
    local x=dx*i
    local coord=ini:Translate(x, heading)
    
    wp[#wp+1]=coord:WaypointGround(speed, formation)
    tasks[#tasks+1]=group:TaskFunction("SUPPRESSION._Passing_Waypoint", self, #wp, false)
    
    env.info(SUPPRESSION.id..string.format("%d x = %4.1f", i, x))
    local MarkerID=coord:MarkToAll(string.format("Waypoing %d of group %s", #wp, self.Controllable:GetName()))
    
  end
  env.info(SUPPRESSION.id..string.format("Total distance: %4.1f", dist))
  
  -- Final waypoint.
  wp[#wp+1]=fin:WaypointGround(speed, formation)
  local MarkerID=fin:MarkToAll(string.format("Waypoing %d of group %s (final)", #wp, self.Controllable:GetName()))
  
    -- Task to hold.
  local ConditionWait=group:TaskCondition(nil, nil, nil, nil, wait, nil)
  local TaskHold = group:TaskHold()
  
  -- Task combo to make group hold at final waypoint.
  local TaskComboFin = {}
  TaskComboFin[#TaskComboFin+1] = group:TaskFunction("SUPPRESSION._Passing_Waypoint", self, #wp, true)
  TaskComboFin[#TaskComboFin+1] = group:TaskControlled(TaskHold, ConditionWait)

  -- Add final task.  
  tasks[#tasks+1]=group:TaskCombo(TaskComboFin)

  -- Original waypoints of the group.
  local Waypoints = group:GetTemplateRoutePoints()
  
  -- New points are added to the default route.
  for i,p in ipairs(wp) do
    table.insert(Waypoints, i, wp[i])
  end
  
  -- Set task for all waypoints.
  for i,wp in ipairs(Waypoints) do
    group:SetTaskWaypoint(Waypoints[i], tasks[i])
  end
  
  -- Submit task and route group along waypoints.
  group:Route(Waypoints)

end

--- Function called when group is passing a waypoint. At the last waypoint we set the group back to CombatReady.
--@param #SUPPRESSION self
--@param #number i Waypoint number that has been reached.
--@param #boolean final True if it is the final waypoint. Start Fightback.
function SUPPRESSION._Passing_Waypoint(group, Fsm, i, final)

  -- Debug message.
  local text=string.format("Group %s passing waypoint %d (final=%s)", group:GetName(), i, tostring(final))
  MESSAGE:New(text,10):ToAllIf(Fsm.debug)
  if Fsm.debug then
    --env.info(SUPPRESSION.id..text)
  end
  env.info(SUPPRESSION.id..text)

  -- Change alarm state back to default.
  if final then
    Fsm:FightBack()
  end  
end


--- Search a place to hide. This is any scenery object in the vicinity.
--@param #SUPPRESSION self
--@return Wrapper.Scenery#SCENERY Hideout scenery object.
--@return nil If no scenery object is within search radius.
function SUPPRESSION:_SearchHideout()
  -- We search objects in a zone with radius ~300 m around the group.
  local Zone = ZONE_GROUP:New("Zone_Hiding", self.Controllable, self.TakecoverRange)

  -- Scan for Scenery objects to run/drive to.
  Zone:Scan(Object.Category.SCENERY)
  
  -- Array with all possible hideouts, i.e. scenery objects in the vicinity of the group.
  local hideouts={}

  for SceneryTypeName, SceneryData in pairs(Zone:GetScannedScenery()) do
    for SceneryName, SceneryObject in pairs(SceneryData) do
    
      local SceneryObject = SceneryObject -- Wrapper.Scenery#SCENERY
      
      if self.debug then
        -- Place markers on every possible scenery object.
        local MarkerID=SceneryObject:GetCoordinate():MarkToAll(string.format("%s scenery object %s", self.Controllable:GetName(),SceneryObject:GetTypeName()))
        local text=string.format("%s scenery: %s, Coord %s", self.Controllable:GetName(), SceneryObject:GetTypeName(), SceneryObject:GetCoordinate():ToStringLLDMS())
        env.info(SUPPRESSION.id..text)
      end
      
      table.insert(hideouts, SceneryObject)
      -- TODO: Add check if scenery name matches a specific type like tree or building. This might be tricky though!
      
    end
  end
  
  -- Get random hideout place.
  local Hideout=nil
  if #hideouts>0 then
  
    if self.debug then
      env.info(SUPPRESSION.id.."Number of hideouts "..#hideouts)
    end
    
    -- Pick a random location.
    Hideout=hideouts[math.random(#hideouts)]
    
  else
    env.error(SUPPRESSION.id.."No hideouts found!")
  end
  
  return Hideout

end

--- Get (relative) life in percent of a group. Function returns the value of the units with the smallest and largest life. Also the average value of all groups is returned.
-- @param #SUPPRESSION self
-- @return #number Smallest life value of all units.
-- @return #number Largest life value of all units.
-- @return #number Average life value of all alife groups
-- @return #number Average life value of all groups including already dead ones.
-- @return #number Relative group strength.
function SUPPRESSION:_GetLife()

  local group=self.Controllable --Wrapper.Group#GROUP
  
  if group and group:IsAlive() then
  
    local units=group:GetUnits()
  
    local life_min=9999
    local life_max=-9999
    local life_ave=0
    local life_ave0=0
    local n=0
    
    local groupstrength=#units/self.IniGroupStrength*100
    
    env.info(SUPPRESSION.id..string.format("Group %s _GetLife nunits = %d", self.Controllable:GetName(), #units))
    
    for _,unit in pairs(units) do
    
      local unit=unit -- Wrapper.Unit#UNIT
      if unit and unit:IsAlive() then
        n=n+1
        local life=unit:GetLife()/(unit:GetLife0()+1)*100
        if life < life_min then
          life_min=life
        end
        if life > life_max then
          life_max=life
        end
        life_ave=life_ave+life
        if self.debug then
          local text=string.format("n=%02d: Life = %3.1f, Life0 = %3.1f, min=%3.1f, max=%3.1f, ave=%3.1f, group=%3.1f", n, unit:GetLife(), unit:GetLife0(), life_min, life_max, life_ave/n,groupstrength)
          env.info(SUPPRESSION.id..text)
        end
      end
      
    end
    
    -- If the counter did not increase (can happen!) return 0
    if n==0 then
      return 0,0,0,0,0
    end
    
    -- Average life relative to initial group strength including the dead ones.
    life_ave0=life_ave/self.IniGroupStrength
    
    -- Average life of all alive units.
    life_ave=life_ave/n    
    
    return life_min, life_max, life_ave, life_ave0, groupstrength
  else
    return 0, 0, 0, 0, 0
  end
end


--- Heading from point a to point b in degrees.
--@param #SUPPRESSION self
--@param Core.Point#COORDINATE a Coordinate.
--@param Core.Point#COORDINATE b Coordinate.
--@return #number angle Angle from a to b in degrees.
function SUPPRESSION:_Heading(a, b, distance)
  local dx = b.x-a.x
  local dy = b.z-a.z
  local angle = math.deg(math.atan2(dy,dx))
  if angle < 0 then
    angle = 360 + angle
  end
  return angle
end

--- Generate Gaussian pseudo-random numbers.
-- @param #SUPPRESSION self
-- @param #number x0 Expectation value of distribution.
-- @param #number sigma (Optional) Standard deviation. Default 10.
-- @param #number xmin (Optional) Lower cut-off value.
-- @param #number xmax (Optional) Upper cut-off value.
-- @return #number Gaussian random number.
function SUPPRESSION:_Random_Gaussian(x0, sigma, xmin, xmax)

  -- Standard deviation. Default 5 if not given.
  sigma=sigma or 5
    
  local r
  local gotit=false
  local i=0
  while not gotit do
  
    -- Uniform numbers in [0,1). We need two.
    local x1=math.random()
    local x2=math.random()
  
    -- Transform to Gaussian exp(-(x-x0)²/(2*sigma²).
    r = math.sqrt(-2*sigma*sigma * math.log(x1)) * math.cos(2*math.pi * x2) + x0
    
    i=i+1
    if (r>=xmin and r<=xmax) or i>100 then
      gotit=true
    end
  end
  
  return r

end

--- Sets the ROE for the group and updates the current ROE variable.
-- @param #SUPPRESSION self
-- @param #string roe ROE the group will get. Possible "Free", "Hold", "Return". Default is self.DefaultROE.
function SUPPRESSION:_SetROE(roe)
  local group=self.Controllable --Wrapper.Controllable#CONTROLLABLE
  
  -- If no argument is given, we take the default ROE.
  roe=roe or self.DefaultROE
  
  -- Update the current ROE.
  self.CurrentROE=roe
  
  -- Set the ROE.
  if roe==SUPPRESSION.ROE.Free then
    group:OptionROEOpenFire()
  elseif roe==SUPPRESSION.ROE.Hold then
    group:OptionROEHoldFire()
  elseif roe==SUPPRESSION.ROE.Return then
    group:OptionROEReturnFire()
  else
    env.error(SUPPRESSION.id.."Unknown ROE requested: "..tostring(roe))
    group:OptionROEOpenFire()
    self.CurrentROE=SUPPRESSION.ROE.Free
  end
  
  local text=string.format("Group %s now has ROE %s.", self.Controllable:GetName(), self.CurrentROE)
  env.info(SUPPRESSION.id..text)
end

--- Sets the alarm state of the group and updates the current alarm state variable.
-- @param #SUPPRESSION self
-- @param #string state Alarm state the group will get. Possible "Auto", "Green", "Red". Default is self.DefaultAlarmState.
function SUPPRESSION:_SetAlarmState(state)
  local group=self.Controllable --Wrapper.Controllable#CONTROLLABLE
  
  -- Input or back to default alarm state.
  state=state or self.DefaultAlarmState
  
  -- Update the current alam state of the group.
  self.CurrentAlarmState=state
  
  -- Set the alarm state.
  if state==SUPPRESSION.AlarmState.Auto then
    group:OptionAlarmStateAuto()
  elseif state==SUPPRESSION.AlarmState.Green then
    group:OptionAlarmStateGreen()
  elseif state==SUPPRESSION.AlarmState.Red then
    group:OptionAlarmStateRed()
  else
    env.error(SUPPRESSION.id.."Unknown alarm state requested: "..tostring(state))
    group:OptionAlarmStateAuto()
    self.CurrentAlarmState=SUPPRESSION.AlarmState.Auto
  end
  
  local text=string.format("Group %s now has Alarm State %s.", self.Controllable:GetName(), self.CurrentAlarmState)
  env.info(SUPPRESSION.id..text)
end

--- Print event-from-to string to DCS log file. 
-- @param #SUPPRESSION self
-- @param #string BA Before/after info.
-- @param #string Event Event.
-- @param #string From From state.
-- @param #string To To state.
function SUPPRESSION:_EventFromTo(BA, Event, From, To)
  if self.debug then
    local text=string.format("%s: %s EVENT %s: %s --> %s", BA, self.Controllable:GetName(), Event, From, To)
    env.info(SUPPRESSION.id..text)
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

