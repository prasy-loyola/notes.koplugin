local logger = require("logger")


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
  ERASER_DOWN = 2,
  ERASER_UP = 3,
}

---@class TouchEvent
---@field x integer
---@field y integer
---@field time integer
---@field type TouchEventType


---@param touchEvent TouchEvent
---@param hook_params any
function noOpListener(touchEvent, hook_params)

end

---@class InputListener
---@field listener fun(touchEvent: TouchEvent, hook_param: any)
---@field slots Slot[]
---@field current_slot Slot
local InputListener = {
  listener = noOpListener

}

---@param listener fun(touchEvent: TouchEvent)
function InputListener:setListener(listener)
  self.listener = listener
end

---An event listener to listen to kernel events directly before being fed into gestureDetector
---As we want to get all the touch events to not lose data in the gestureDetector
---@param event KernelEvent
---@param hook_params any
function InputListener:eventAdjustmentHook(input, event, hook_params)
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
        self.current_slot.value = event.value
        return
      end
      self.slots[event.value] = {}
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
      if self.current_slot and self.current_slot.toolType and self.current_slot.toolType == 1 then
        self.current_slot = nil
      end
    end
  elseif event.type == events.EV_SYN then
    if event.code == mtCodes.SYN_REPORT and self.current_slot then
      local touchEventType = TouchEventType.PEN_DOWN;
      if self.current_slot.isEraser then
        if self.current_slot.value == 0 then
          touchEventType = TouchEventType.ERASER_UP
        elseif self.current_slot.value == 0 then
          touchEventType = TouchEventType.ERASER_DOWN
        end
      end
      ---@type TouchEvent
      local touchEvent = { x = self.current_slot.x, y = self.current_slot.y, time = (event.time.sec * 1000000 + event.time.usec), type =
      touchEventType };
      logger.dbg("InputListener: TouchEvent", touchEvent);
      self.listener(touchEvent, hook_params)
      self.slots[self.current_slot["id"]] = nil
      self.current_slot = nil
    end
  end
end

InputListener.TouchEventType = TouchEventType

return InputListener
