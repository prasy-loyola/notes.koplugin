--[[
-- This is the notes widget which is going to do the drawing
--]]

local logger = require("logger")
local Blitbuffer = require("ffi/blitbuffer")
local Geom = require("ui/geometry")
local UIManager = require("ui/uimanager")
local Widget = require("ui/widget/widget")
local Screen = require("device").screen

local NotesWidget = Widget:new {
  -- dimen = Geom:new { w = 0, h = 0 },
  dimen = Geom:new {
    w = Screen:getSize().w * 0.95,
    h = Screen:getSize().h * 0.9,
  },
  points = {},
}

function NotesWidget:init()
  logger.info("NotesWidget:init()")
end

function NotesWidget:getSize()
  -- local size = Geom:new {
  --   w = Screen:getSize().w * 0.8,
  --   h = Screen:getSize().h * 0.6,
  -- }
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
  logger.info("NotesWidget:handleEvent", event.args[1].ges, event.args[1].pos);
  local pos = event.args[1].pos
  if pos == nil then
    return false
  end


  table.insert(self.points, { x = pos.x, y = pos.y })
  local tx = pos.x - self.dimen.x;
  local ty = pos.y - self.dimen.y;

  if tx < 0 or tx > self.dimen.w or tx < 0 or ty > self.dimen.h then
    return false;
  end

  logger.dbg("Touch: tx", tx, "ty", ty);
  self.bb:paintRect(tx, ty, 10, 10, Blitbuffer.COLOR_WHITE)

  UIManager:setDirty(self, function()
    return "ui", self.dimen
  end);

  return true
end

return NotesWidget
