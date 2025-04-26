--[[
-- This is the notes widget which is going to do the drawing
--]]

local logger = require("logger")
local Blitbuffer = require("ffi/blitbuffer")
local Geom = require("ui/geometry")
local UIManager = require("ui/uimanager")
local Widget = require("ui/widget/widget")
local Screen = require("device").screen
local InputListener = require("./inputlistener")
require("./inputlistener")

---@class BlitBuffer
---@field paintRect fun(x: integer, y: integer, w: integer, h:integer, value: any, setter: any)
---@field paintRectRGB32 fun(x: integer, y: integer, w: integer, h:integer, value: any, setter: any)

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
---@field isRunning boolean
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

---comment
---@param tEvent TouchEvent
---@param hook_params any
function NotesWidget:touchEventListener(tEvent, hook_params)
  if not self.isRunning or not tEvent then
    return
  end
  if tEvent.type == InputListener.TouchEventType.ERASER_DOWN then
    self.penColor = WHITE
    self.brushSize = ERASER_BRUSH_SIZE
  elseif tEvent.type == InputListener.TouchEventType.ERASER_UP then
    self.penColor = RED
    self.brushSize = PEN_BRUSH_SIZE
  elseif tEvent.type == InputListener.TouchEventType.PEN_HOVER or
      tEvent.type == InputListener.TouchEventType.ERASER_HOVER then
    return
  end

  logger.dbg("Rotation mode", Screen:getRotationMode());
  logger.dbg("Rotation", Screen.rotation);

  local tx = tEvent.x - self.dimen.x;
  local ty = tEvent.y - self.dimen.y;
  --- Boundary check
  if tx < 0 or tx > self.dimen.w or tx < 0 or ty > self.dimen.h then
    return;
  end
  tEvent.x = tx
  tEvent.y = ty
  table.insert(self.touchEvents, tEvent)
  -- self:paintToBB(); -- reduce the number of redraws
  if #self.touchEvents < 2 then
    self.bb:paintRectRGB32(tx, ty, self.brushSize, self.brushSize, self.penColor);
  else
    local prevTEvent = self.touchEvents[#self.touchEvents - 1]
    local tEvent = self.touchEvents[#self.touchEvents]

    if tEvent.time - prevTEvent.time < self.strokeTime and tEvent.toolType == prevTEvent.toolType then
      self:interPolate(prevTEvent, tEvent);
    else
      self.bb:paintRectRGB32(tEvent.x, tEvent.y, self.brushSize, self.brushSize, self.penColor);
    end
  end
  UIManager:setDirty(self, function()
    return "ui", self.dimen
  end);
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
      if tEvent.time - prevTEvent.time < self.strokeTime and tEvent.toolType == prevTEvent.toolType then
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
