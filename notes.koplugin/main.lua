--[[
This plugin provides a Handwritten notes
]]

local logger = require("logger")
local Blitbuffer = require("ffi/blitbuffer")
local Dispatcher = require("dispatcher")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Widget = require("ui/widget/widget")
local _ = require("gettext")


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

function NotesWidget:paintTo(bb, x, y) 
  logger.info("NotesWidget:paintTo");
  logger.info(bb);
  local black = Blitbuffer.COLOR_BLACK
  bb:paintRect(self.x, self.y, 2, 2, black)
  UIManager:setDirty("ui", "full")
end


function NotesWidget:handleEvent(event)
  logger.info("NotesWidget:handleEvent");
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
  logger.info("x, y", self.x, self.y)
  UIManager:show(self)

  return true
end

local Notes = WidgetContainer:new {
  name = "notes",
  is_doc_only = false,
  scale_factor = 1,
}

function Notes:init()
  logger.info("Notes:init");
  self:onDispatcherRegisterActions()

  self.ui.menu:registerToMainMenu(self)
end

function Notes:onNotesStart()
  logger.info("Notes starting");
  UIManager:show(NotesWidget);
end


function Notes:onDispatcherRegisterActions()
  Dispatcher:registerAction("show_notes",
    { category = "none", event = "NotesStart", title = _("Notes"), device = true })
end

function Notes:addToMainMenu(menu_items)
  menu_items.notes = {
    text = _("Notes"),
    -- sorting_hint = "more_tools",
    keep_menu_open = true,
    callback = function()
      self:onNotesStart()
    end,
  }
end

return Notes
