--[[
-- This is the notes widget which is going to do the drawing
--]]

local logger = require("logger")
local Blitbuffer = require("ffi/blitbuffer")
local Geom = require("ui/geometry")
local UIManager = require("ui/uimanager")
local Widget = require("ui/widget/widget")
local Screen = require("device").screen


---@class Slot
---@field x integer
---@field y integer
---@field time integer
---@field toolType integer

---@class TouchEvent
---@field x integer
---@field y integer
---@field time integer
---@field ges string


---TODO: find a way to document functions in Ldoc
---@class BlitBuffer
---@field paintRect function
---@field paintRectRGB32 function



local RED = Blitbuffer.colorFromName("red")
local WHITE = Blitbuffer.colorFromString("#ffffff")
local PEN_BRUSH_SIZE = 3
local ERASER_BRUSH_SIZE = PEN_BRUSH_SIZE * 3
---@class NotesWidget
---@field dimen any
---@field touchEvents TouchEvent[]
---@field bb BlitBuffer
---@field brushSize integer
---@field penColor integer
---@field backgroundColor integer
---@field strokeTime integer
---@field strokeDelay integer
---@field kernelEventListener function
---@field slots Slot[]
---@field current_slot Slot
local NotesWidget = Widget:new {
  dimen = Geom:new {
    w = Screen:getSize().w * 0.95,
    h = Screen:getSize().h * 0.95,
  },
  touchEvents = {},
  brushSize = 3,
  backgroundColor = WHITE,
  penColor = RED,
  strokeDelay = 10 * 1000,
  strokeTime = 60 * 1000,
  slots = {},
  current_slot = nil,
}

function NotesWidget:init()
  logger.info("NotesWidget:init()")
end

function NotesWidget:getSize()
  return self.dimen;
end

function NotesWidget:paintTo(bb, x, y)
  self.dimen.x = x;
  self.dimen.y = y;
  if not self.dimen or self.dimen.x == 0 or self.dimen.y == 0 then
    return
  end
  if not self.bb then
    self.bb = Blitbuffer.new(self.dimen.w, self.dimen.h, Blitbuffer.TYPE_BBRGB32);
    self.bb:paintRectRGB32(0, 0, self.dimen.w, self.dimen.h, self.backgroundColor);
  end
  logger.dbg("NotesWidget:paintTo", x, y);
  bb:blitFrom(self.bb, x, y, 0, 0, self.dimen.w, self.dimen.h)
  logger.dbg("NotesWidget:paintTo dimen: ", self.dimen);
end

---comment
---@param p1 TouchEvent
---@param p2 TouchEvent
function NotesWidget:interPolate(p1, p2)
  if not p1 or not p2 then
    return
  end
  self.bb:paintRectRGB32(p1.x, p1.y, self.brushSize, self.brushSize, self.penColor);
  self.bb:paintRectRGB32(p2.x, p2.y, self.brushSize, self.brushSize, self.penColor);
  if p1.x == p2.x and p1.y == p2.y then
    return
  end
  local x0 = p1.x < p2.x and p1.x or p2.x
  local x1 = p1.x > p2.x and p1.x or p2.x
  local y0 = p1.x < p2.x and p1.y or p2.y
  local y1 = p1.x > p2.x and p1.y or p2.y

  local xDiff = x1 - x0

  for x = x0 + 1, x1, 1 do
    local y = math.floor(((y0 * (x1 - x)) + (y1 * (x - x0))) / xDiff)
    if x == 0 or y == 0 then return end
    self.bb:paintRectRGB32(x, y, self.brushSize, self.brushSize, self.penColor);
  end

  x0 = p1.y < p2.y and p1.x or p2.x
  x1 = p1.y > p2.y and p1.x or p2.x
  y0 = p1.y < p2.y and p1.y or p2.y
  y1 = p1.y > p2.y and p1.y or p2.y

  local yDiff = y1 - y0
  for y = y0 + 1, y1, 1 do
    local x = math.floor(((x0 * (y1 - y)) + (x1 * (y - y0))) / yDiff)
    if x == 0 or y == 0 then return end
    self.bb:paintRectRGB32(x, y, self.brushSize, self.brushSize, self.penColor);
  end
end

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

---An event listener to listen to kernel events directly before being fed into gestureDetector
---As we want to get all the touch events to not lose data in the gestureDetector
---@param event KernelEvent
---@param hook_params any
function NotesWidget:kernelEventListener(input, event, hook_params)
  if not self.slots then
    self.slots = {}
  end

  if event.code == mtCodes.Eraser then
    logger.dbg("Got an eraser event", event.code, event.value);
    if event.value == 0 then
      self.penColor = RED
      self.brushSize = PEN_BRUSH_SIZE
    elseif event.value == 1 then
      self.penColor = WHITE
      self.brushSize = ERASER_BRUSH_SIZE
    end
  end

  if event.type ~= events.EV_SYN and event.type ~= events.EV_ABS then
    return
  end

  if event.type == events.EV_ABS then
    if event.code == mtCodes.ABS_MT_SLOT or event.code == mtCodes.ABS_MT_TRACKING_ID then
      self.slots[event.value] = {}
      self.current_slot = self.slots[event.value]
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
    if event.code == mtCodes.SYN_REPORT and self.current_slot and self.current_slot.x and self.current_slot.y then
      local tx = self.current_slot.x - self.dimen.x;
      local ty = self.current_slot.y - self.dimen.y;
      --- Boundary check
      if tx < 0 or tx > self.dimen.w or tx < 0 or ty > self.dimen.h then
        return;
      end
      table.insert(self.touchEvents, { x = tx, y = ty, time = (event.time.sec * 1000000 + event.time.usec) })
      -- self:paintToBB(); -- reduce the number of redraws
      if #self.touchEvents < 2 then
        self.bb:paintRectRGB32(tx, ty, self.brushSize, self.brushSize, self.penColor);
      else
        local prevTEvent = self.touchEvents[#self.touchEvents - 1]
        local tEvent = self.touchEvents[#self.touchEvents]

        if tEvent.time - prevTEvent.time < self.strokeTime then
          self:interPolate(prevTEvent, tEvent);
        else
          self.bb:paintRectRGB32(tEvent.x, tEvent.y, self.brushSize, self.brushSize, self.penColor);
        end
      end
      UIManager:setDirty(self, function()
        return "ui", self.dimen
      end);
      self.current_slot = nil
      self.slots = {}
    end
  end
end

function NotesWidget:paintToBB()
  if #self.touchEvents < 1 then
    return true
  end

  for index, tEvent in ipairs(self.touchEvents) do
    if index == 1 then
      self.bb:paintRect(tEvent.x, tEvent.y, self.brushSize, self.brushSize, self.penColor);
    else
      local prevTEvent = self.touchEvents[index - 1]
      if tEvent.time - prevTEvent.time < self.strokeTime then
        self:interPolate(prevTEvent, tEvent);
      else
        self.bb:paintRectRGB32(tEvent.x, tEvent.y, self.brushSize, self.brushSize, self.penColor);
      end
    end
  end

  UIManager:setDirty(self, function()
    return "ui", self.dimen
  end);
end

return NotesWidget
