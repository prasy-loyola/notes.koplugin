--[[
This plugin provides a Handwritten notes
]]

local logger = require("logger")
local Blitbuffer = require("ffi/blitbuffer")
local Dispatcher = require("dispatcher")
local FrameContainer = require("ui/widget/container/framecontainer")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Widget = require("ui/widget/widget")
local Size = require("ui/size")
local _ = require("gettext")
local Screen = require("device").screen


--[[
-- This is the notes widget which is going to do the drawing
--]]

local NotesWidget = Widget:new {
  x = 10,
  y = 10,
}

function NotesWidget:init()
  logger.info("NotesWidget:init()")
end

function NotesWidget:getSize()
  local size = Screen:getSize()
  return {
    w = size.w - 100,
    h = size.h - 100,
  }
end

function NotesWidget:paintTo(bb, x, y)
  logger.dbg("NotesWidget:paintTo");
  local black = Blitbuffer.COLOR_BLACK
  bb:paintRect(self.x, self.y, 2, 2, black)
end

function NotesWidget:handleEvent(event)
  logger.dbg("NotesWidget:handleEvent");
  -- logger.info(event["args"])
  if event.args == nil then
    return false
  end
  if #event.args < 1 then
    return false
  end
  local pos = event.args[1].pos
  if pos == nil then
    return false
  end

  self.x = pos.x;
  self.y = pos.y;
  UIManager:show(self)

  return true
end

local frame = FrameContainer:new {
  radius = Size.radius.window,
  bordersize = Size.border.window,
  padding = 0,
  margin = 50,
  background = Blitbuffer.COLOR_WHITE,
  VerticalGroup:new {
    [1] = NotesWidget
  }
}

local Notes = WidgetContainer:new {
  name = "notes",
  is_doc_only = false,
  scale_factor = 1,
}

function Notes:init()
  logger.dbg("Notes:init");
  self:onDispatcherRegisterActions()

  self.ui.menu:registerToMainMenu(self)
end

function Notes:onNotesStart()
  logger.dbg("Notes starting");
  UIManager:show(frame);
end

function Notes:onDispatcherRegisterActions()
  Dispatcher:registerAction("show_notes",
    { category = "none", event = "NotesStart", title = _("Notes"), device = true })
end

function Notes:addToMainMenu(menu_items)
  menu_items.notes = {
    text = _("Notes"),
    -- sorting_hint = "more_tools",
    -- keep_menu_open = true,
    callback = function()
      self:onNotesStart()
    end,
  }
end

return Notes
