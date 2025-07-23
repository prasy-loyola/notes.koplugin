local logger = require("logger")
local Device = require("device")
local Screen = require("device").screen

local Input = require("device/input")

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
---@field slot integer

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


---@enum ToolSubType
local ToolSubType = {
  FINGER = 0,
  PEN = 1,
  ERASER = 2,
}


ToolSubType.PrintNames = {
  [ToolSubType.FINGER] = "FINGER",
  [ToolSubType.PEN] = "PEN",
  [ToolSubType.ERASER] = "ERASER",
}

---@class TouchEvent
---@field x integer
---@field y integer
---@field time integer
---@field type TouchEventType
---@field toolType ToolType
---@field slot integer
local TouchEvent = {}

function TouchEvent:__tostring()
  return "ToolType:" ..
      ToolType.PrintNames[self.toolType] ..
      " Type:" .. TouchEventType.PrintNames[self.type] ..
      " x:" .. (self.x and tostring(self.x) or "nil") ..
      " y:" .. (self.y and tostring(self.y) or "nil") ..
      " time:" .. tostring(self.time) ..
      " slot:" .. tostring(self.slot)
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

InputListener.ToolSubType = ToolSubType;
function InputListener:cleanupGestureDetector()
  if not self.original_feedEvent then
    Input.gesture_detector.feedEvent = self.original_feedEvent
  end
end

function InputListener:setupGestureDetector()
  if not self.original_feedEvent then
    self.original_feedEvent = Device.input.gesture_detector.feedEvent
  end

  logger.dbg(self.original_feedEvent)

  if self.original_feedEvent then
    Device.input.gesture_detector.feedEvent = function(s, ev)
      InputListener:feedEvent(ev);
      return self.original_feedEvent(s, ev);
    end
  end
end

---@param listener fun(touchEvent: TouchEvent)
function InputListener:setListener(listener)
  self.listener = listener
end

---@param event Slot
---@return TouchEvent
function InputListener:createTouchEvent(event, time)
  if not event then
    return {}
  end
  local touchEventType = TouchEventType.PEN_DOWN;
  if event.subtool == ToolSubType.ERASER then
    logger.dbg("NW: Setting EraserDown")
    touchEventType = TouchEventType.ERASER_DOWN
  end

  local rotation = self.screen:getRotationMode();

  local x, y
  if rotation == self.screen.DEVICE_ROTATED_COUNTER_CLOCKWISE then
    -- 3
    local height = self.screen:getHeight()
    x, y = (event.y), (height - event.x)
  elseif rotation == self.screen.DEVICE_ROTATED_CLOCKWISE then
    -- 2
    local width = self.screen:getWidth()
    x, y = (width - event.y), (event.x)
  elseif rotation == self.screen.DEVICE_ROTATED_UPSIDE_DOWN then
    -- 1
    local height = self.screen:getHeight()
    local width = self.screen:getWidth()
    x, y = (width - event.x), (height - event.y)
  elseif rotation == self.screen.DEVICE_ROTATED_UPRIGHT then
    -- 0
    x, y = event.x, event.y
  end

  if x > self.screen:getWidth() or y > self.screen:getHeight() then
    return nil
  end

  ---@type TouchEvent
  return TouchEvent:new {
    x = x,
    y = y,
    time = event.timev,
    type = touchEventType,
    toolType = event.toolType or ToolType.FINGER,
    slot = event.slot
  }
end

function print_objs(...)
  local args = { ... }
  local printResult = ""
  for i, ev in ipairs(args) do
    if not printResult == "" then
      printResult = printResult .. "\n"
    end
    for k, v in pairs(ev) do
      printResult = printResult .. k .. ':' .. v .. ' '
    end
  end
  return printResult
end

function InputListener:feedEvent(events)
  logger.dbg("NW: Got Events: ", #events)

  for _, ev in ipairs(events) do
    if ev["id"] == -1 then
      logger.dbg("NW: Ignoring ev: " .. print_objs(ev))
    else
      --- if the ev.id is not the same as the eraser_id but subtool is set as eraser
      --- that means the subtool is not cleared yet
      if ev.subtool == ToolSubType.ERASER and ev.id ~= self.eraser_id then
        Device.input:setCurrentMtSlotChecked("subtool", nil)
        ev.subtool = nil
      end
      logger.dbg('NW: Processing ev:' .. print_objs(ev))
      local touchEvent = self:createTouchEvent(ev);
      if touchEvent then
        logger.dbg("NW: TouchEvent", tostring(touchEvent))
        self.listener(touchEvent, hook_params)
      end
    end
  end


  return {}
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
    logger.dbg('Read TEV:' .. event.type .. ',' .. event.code ..
      ',' .. event.value .. ',' .. event.time.sec .. ',' .. event.time.usec)
    self:eventAdjustmentHook(input, event, hook_params)
  end
end

---An event listener to listen to kernel events directly before being fed into gestureDetector
---As we want to get all the touch events to not lose data in the gestureDetector
---@param event KernelEvent
---@param hook_params any
function InputListener:eventAdjustmentHook(input, event, hook_params)
  if event.code == mtCodes.ABS_MT_TRACKING_ID then
    self.current_tracking_id = event.value
  end

  if event.code == mtCodes.Eraser and event.value == 1 then
    logger.dbg("NW: Setting subtool as Eraser")
    Device.input:setCurrentMtSlotChecked("subtool", ToolSubType.ERASER)
    self.eraser_id = self.current_tracking_id
    logger.dbg("NW: eraser_id:" .. self.eraser_id)
  end
end

InputListener.TouchEventType = TouchEventType

return InputListener
