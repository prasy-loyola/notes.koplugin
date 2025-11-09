local logger = require("logger")
local Device = require("device")
local Screen = require("device").screen
local Input = require("device/input")

--[[
-- Parsing raw Kernel events is hard and needs to be supportd for every device.
-- Device.Input module in Koreader core already parses the raw kernel events
-- and creates a TouchEvent object with multiple slots wherever multi touch is supported
-- Koreader core doesn't provide a way to read these parsed events directly, so
-- what we do is we swap out the GestureDetector inside the Device.input with a function
-- which feeds the parsed events into our own listener, and we are free to use these
-- events to draw on the buffer.
--
-- We have to be careful to put back the original gesture_detector when we don't show the widget
-- so that general system gestures work when the widget is not displayed
--]]

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
  KOBO_STYLUS_ERASER = 331,
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
  ERASER_DOWN = 1,
}
TouchEventType.PrintNames = {
  [TouchEventType.PEN_DOWN] = "PEN_DOWN",
  [TouchEventType.ERASER_DOWN] = "ERASER_DOWN",
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
  return "ToolType:" .. ToolType.PrintNames[self.toolType] ..
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
---@field screen
local InputListener = {
  listener = noOpListener,
  screen = Screen
}

InputListener.ToolSubType = ToolSubType;
InputListener.TouchEventType = TouchEventType
InputListener.ToolType = ToolType

---This function needs to be called when the touch events need to be processed by the widget, normally when widget is displayed
function InputListener:setupGestureDetector()
  if not self.original_feedEvent then
    self.original_feedEvent = Device.input.gesture_detector.feedEvent
  end

  if self.original_feedEvent then
    Device.input.gesture_detector.feedEvent = function(s, ev)
      self:__feedEvent(ev);
      return self.original_feedEvent(s, ev);
    end
  end
end

---This function needs to be called when we no longer want to process the touch events
function InputListener:cleanupGestureDetector()
  if not self.original_feedEvent then
    Device.input.gesture_detector.feedEvent = self.original_feedEvent
  end
end

---Set the listener to receive the TouchEvents
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

  if (not (self.screen:getWidth() and self.screen:getHeight() and x and y))
      or x > self.screen:getWidth() or y > self.screen:getHeight() then
    return nil
  end

  ---@type TouchEvent
  return TouchEvent:new {
    x = x,
    y = y,
    time = event.timev,
    type = touchEventType,
    toolType = event.tool or ToolType.FINGER,
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

function InputListener:__feedEvent(events)
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

---An event listener to listen to kernel events directly before being fed into gestureDetector
---As we want to get all the touch events to not lose data in the gestureDetector
---@param event KernelEvent
---@param hook_params any
function InputListener:eventAdjustmentHook(input, event, hook_params)
  if Device.isKobo then
    if event.code == mtCodes.ABS_MT_TRACKING_ID then
      self.current_tracking_id = event.value
    end

    if event.code == mtCodes.KOBO_STYLUS_ERASER and event.value == 1 then
      logger.dbg("NW: Setting subtool as Eraser")
      Device.input:setCurrentMtSlotChecked("subtool", ToolSubType.ERASER)
      self.eraser_id = self.current_tracking_id
      logger.dbg("NW: eraser_id:" .. self.eraser_id)
    end
  end
end

return InputListener
