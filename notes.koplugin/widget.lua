--[[
-- This is the notes widget which is going to do the drawing
--]]

local logger = require("logger")
local Blitbuffer = require("ffi/blitbuffer")
local Geom = require("ui/geometry")
local UIManager = require("ui/uimanager")
local Widget = require("ui/widget/widget")
local Screen = require("device").screen

---@class TouchEvent
---@field x integer
---@field y integer
---@field time integer


---TODO: find a way to document functions in Ldoc
---@class BlitBuffer
---@field paintRect function

---@class NotesWidget
---@field dimen any
---@field touchEvents TouchEvent[]
---@field bb BlitBuffer
---@field brushSize integer
---@field penColor integer
---@field strokeTime integer

---@type NotesWidget
local NotesWidget = Widget:new {
  -- dimen = Geom:new { w = 0, h = 0 },
  dimen = Geom:new {
    w = Screen:getSize().w * 0.95,
    h = Screen:getSize().h * 0.9,
  },
  touchEvents = {},
  brushSize = 3,
  penColor = Blitbuffer.COLOR_WHITE,
  strokeTime = 300 * 1000,

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
    self.bb = Blitbuffer.new(NotesWidget.dimen.w, NotesWidget.dimen.h);
  end
  logger.dbg("NotesWidget:paintTo", x, y);
  bb:blitFrom(self.bb, x, y, 0, 0, self.dimen.w, self.dimen.h)
  logger.dbg("NotesWidget:paintTo dimen: ", self.dimen);
end

function NotesWidget:handleEvent(event)
  if event.args == nil then
    return false
  end
  if #event.args < 1 or not event.args[1] then
    return false
  end
  logger.info("NotesWidget:handleEvent", event.args[1].ges, event.args[1].pos, event.args[1].time);
  logger.info("NotesWidget:handleEvent", event);
  local pos = event.args[1].pos
  if pos == nil then
    return false
  end
  if event.args[1].ges == "swipe"
      or event.args[1].ges == "multiswipe"
  then
    return false
  end

  local tx = pos.x - self.dimen.x;
  local ty = pos.y - self.dimen.y;

  if tx < 0 or tx > self.dimen.w or tx < 0 or ty > self.dimen.h then
    return false;
  end

  table.insert(self.touchEvents, { x = tx, y = ty, time = event.args[1].time })

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
        self.bb:paintRect(tEvent.x, tEvent.y, self.brushSize, self.brushSize, self.penColor);
      end
    end
  end

  UIManager:setDirty(self, function()
    return "ui", self.dimen
  end);

  return true
end

---comment
---@param p1 TouchEvent
---@param p2 TouchEvent
function NotesWidget:interPolate(p1, p2)
  if not p1 or not p2 then
    logger.info("p1", p1, "p2", p2)
    return
  end
  if p1.x == p2.x and p1.y == p2.y then
    self.bb:paintRect(p1.x, p1.y, self.brushSize, self.brushSize, self.penColor);
    return
  end
  local x0 = p1.x < p2.x and p1.x or p2.x
  local x1 = p1.x > p2.x and p1.x or p2.x
  local y0 = p1.y < p2.y and p1.y or p2.y
  local y1 = p1.y > p2.y and p1.y or p2.y

  local xDiff = x1 - x0

  for x = x0, x1, 1 do
    local y = math.floor(((y0 * (x1 - x)) + (y1 * (x - x0))) / xDiff)
    if y == 0 then return end
    self.bb:paintRect(x, y, self.brushSize, self.brushSize, self.penColor);
  end
  local yDiff = y1 - y0
  for y = y0, y1, 1 do
    local x = math.floor(((x0 * (y1 - y)) + (x1 * (y - y0))) / yDiff)
    if x == 0 then return end
    self.bb:paintRect(x, y, self.brushSize, self.brushSize, self.penColor);
  end
end

return NotesWidget
