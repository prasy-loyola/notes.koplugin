local logger = require("logger")
local Screen = require("device").screen


---@enum EventType
local events = {
  EV_SYN = 0,
  EV_ABS = 3,
}

---@enum MultiTouchCodes
local mtCodes = {
  SYN_REPORT = 0,
  ABS_MT_SLOT = 47,
  ABS_MT_POSITION_X = 53,
  ABS_MT_POSITION_Y = 54,
  ABS_MT_TOOL_TYPE = 55,
  ABS_MT_TRACKING_ID = 57,
  Eraser = 331,
}

---@class Time
---@field sec integer seconds
---@field usec integer microseconds

---@class KernelEvent
---@field type EventType
---@field code MultiTouchCodes
---@field time Time
---@field value integer

---@class Slot
---@field x integer
---@field y integer
---@field time integer
---@field toolType integer
---@field isEraser boolean
---@field value integer

---@enum TouchEventType
local TouchEventType = {
  PEN_DOWN = 0,
  PEN_UP = 1,
  PEN_HOVER = 2,
  ERASER_DOWN = 3,
  ERASER_UP = 4,
  ERASER_HOVER = 5,
}

TouchEventType.PrintNames = {
  [TouchEventType.PEN_DOWN] = "PEN_DOWN",
  [TouchEventType.PEN_UP] = "PEN_UP",
  [TouchEventType.PEN_HOVER] = "PEN_HOVER",
  [TouchEventType.ERASER_DOWN] = "ERASER_DOWN",
  [TouchEventType.ERASER_UP] = "ERASER_UP",
  [TouchEventType.ERASER_HOVER] = "ERASER_HOVER",
}


---@enum ToolType
local ToolType = {
  FINGER = 0,
  PEN = 1,
}

ToolType.PrintNames = {
  [ToolType.FINGER] = "FINGER",
  [ToolType.PEN] = "PEN",
}


---@class TouchEvent
---@field x integer
---@field y integer
---@field time integer
---@field type TouchEventType
---@field toolType ToolType
local TouchEvent = {}

function TouchEvent:__tostring()
  return "ToolType:" ..
      ToolType.PrintNames[self.toolType] ..
      " Type:" .. TouchEventType.PrintNames[self.type] ..
      " x:" .. (self.x and tostring(self.x) or "nil") ..
      " y:" .. (self.y and tostring(self.y) or "nil") ..
      " time:" .. tostring(self.time)
end

---@return TouchEvent
function TouchEvent:new(o)
  setmetatable(o, self)
  self.__index = self
  return o
end

---@param touchEvent TouchEvent
---@param hook_params any
function noOpListener(touchEvent, hook_params)

end

---@class InputListener
---@field listener fun(touchEvent: TouchEvent, hook_param: any)
---@field slots Slot[]
---@field current_slot Slot
---@field penHovering boolean
local InputListener = {
  listener = noOpListener,
  screen = Screen
}

---@param listener fun(touchEvent: TouchEvent)
function InputListener:setListener(listener)
  self.listener = listener
end

---@param slot Slot
---@return TouchEvent
function InputListener:createTouchEvent(slot, time)
  if not slot then
    return {}
  end
  local touchEventType = TouchEventType.PEN_DOWN;
  if slot.isEraser then
    if slot.value == 0 then
      touchEventType = TouchEventType.ERASER_UP
    elseif slot.value == 1 then
      touchEventType = TouchEventType.ERASER_DOWN
    elseif slot.value == -1 then
      touchEventType = TouchEventType.ERASER_HOVER
    end
  end
  if slot.value == -1 then
    touchEventType = TouchEventType.PEN_HOVER
  end

  local rotation = self.screen:getRotationMode();

  local x, y
  if rotation == self.screen.DEVICE_ROTATED_COUNTER_CLOCKWISE then
    -- 3
    local height = self.screen:getHeight()
    x, y = (slot.y), (height - slot.x)
  elseif rotation == self.screen.DEVICE_ROTATED_CLOCKWISE then
    -- 2
    local width = self.screen:getWidth()
    x, y = (width - slot.y), (slot.x)
  elseif rotation == self.screen.DEVICE_ROTATED_UPSIDE_DOWN then
    -- 1
    local height = self.screen:getHeight()
    local width = self.screen:getWidth()
    x, y = (width - slot.x), (height - slot.y)
  elseif rotation == self.screen.DEVICE_ROTATED_UPRIGHT then
    -- 0
    x, y = slot.x, slot.y
  end


  ---@type TouchEvent
  return TouchEvent:new {
    x = x,
    y = y,
    time = (time.sec * 1000000) + time.usec,
    type = touchEventType,
    toolType = slot.toolType or ToolType.FINGER
  }
end

function InputListener:runTest(input, hook_params)
  local f, err, str;
  f, err = io.open('/mnt/onboard/.adds/koreader/plugins/notes.koplugin/touch-input.csv', 'r');
  if not f then
    logger.err('Couldnt open file');
    return
  end
  str, err = f:read("*a")
  if not str then
    logger.err('Couldnt read file');
    return
  end
  logger.info("Read touch-input.csv")

  local starting_tracking_id = self.last_tracking_id + 1
  for type, code, value, sec, usec in string.gmatch(str, '(%d+),(%d+),([-%d]+),(%d+),(%d+)[\r\n]+') do
    
    local event = {
      type = tonumber(type),
      code = tonumber(code),
      value = tonumber(value),
      time = {
        sec = tonumber(sec),
        usec = tonumber(usec)
      }
    }
    if event.type == 3 and event.code == 57 then
      event.value = starting_tracking_id
    end
    logger.info('Read TEV:' .. event.type .. ',' .. event.code ..
      ',' .. event.value .. ',' .. event.time.sec .. ',' .. event.time.usec)
    self:eventAdjustmentHook(input, event, hook_params)
  end
end

---An event listener to listen to kernel events directly before being fed into gestureDetector
---As we want to get all the touch events to not lose data in the gestureDetector
---@param event KernelEvent
---@param hook_params any
function InputListener:eventAdjustmentHook(input, event, hook_params)
  logger.info('TEV:' .. event.type .. ',' .. event.code ..
    ',' .. event.value .. ',' .. event.time.sec .. ',' .. event.time.usec)
  if not self.slots then
    self.slots = {}
  end

  if event.code == mtCodes.Eraser and self.current_slot then
    self.current_slot.isEraser = true
    self.current_slot.value = event.value
  end

  if event.type ~= events.EV_SYN and event.type ~= events.EV_ABS then
    return
  end

  if event.type == events.EV_ABS then
    if event.code == mtCodes.ABS_MT_SLOT or event.code == mtCodes.ABS_MT_TRACKING_ID then
      if event.value == -1 and self.current_slot then
        local touchEvent = self:createTouchEvent(self.current_slot, event.time);
        if not (touchEvent.x and touchEvent.y and touchEvent.time and touchEvent.type) then
          logger.dbg("Incomplete touchEvent =>" .. tostring(touchEvent), self.current_slot)
        else
          logger.dbg("TouchEvent: " .. tostring(touchEvent));
          self.listener(touchEvent, hook_params)
        end
        return
      end
      if not self.slots[event.value] then
        self.slots[event.value] = {}
        if (self.last_tracking_id or 0 ) < event.value then
          self.last_tracking_id = event.value
          logger.dbg("Set last_tracking_id:"..self.last_tracking_id)
        end
      end
      self.current_slot = self.slots[event.value]
      self.current_slot["id"] = event.value
    elseif event.code == mtCodes.ABS_MT_POSITION_X then
      if self.current_slot then
        self.current_slot.x = event.value
      end
    elseif event.code == mtCodes.ABS_MT_POSITION_Y then
      if self.current_slot then
        self.current_slot.y = event.value
      end
    elseif event.code == mtCodes.ABS_MT_TOOL_TYPE then
      if self.current_slot then
        self.current_slot.toolType = event.value
      end
    elseif event.code == input.pressure_event and event.value == 0 then
      -- ignoring hover events from stylus pens
      if self.current_slot and self.current_slot.toolType and self.current_slot.toolType == 1 then
        self.current_slot.value = -1
      end
    end
  elseif event.type == events.EV_SYN then
    if event.code == mtCodes.SYN_REPORT then
      if not self.current_slot then
        return
      end

      local touchEvent = self:createTouchEvent(self.current_slot, event.time);
      if not (touchEvent.x and touchEvent.y and touchEvent.time and touchEvent.type) then
        logger.dbg("Incomplete touchEvent =>" .. tostring(touchEvent), self.current_slot)
      else
        logger.dbg("TouchEvent: " .. tostring(touchEvent));
        self.listener(touchEvent, hook_params)
      end

      self.slots[self.current_slot["id"]] = nil
      self.contacts = {}
      self.current_slot = nil
    end
  else
    logger.dbg("Ignoring: ")
  end
end

InputListener.TouchEventType = TouchEventType

return InputListener
