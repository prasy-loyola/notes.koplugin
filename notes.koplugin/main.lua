--[[
This plugin provides a Handwritten notes
]]

local logger = require("logger")
local Blitbuffer = require("ffi/blitbuffer")
local Dispatcher = require("dispatcher")
local FrameContainer = require("ui/widget/container/framecontainer")
local Input = require("device/input")
local TitleBar = require("ui/widget/titlebar")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Size = require("ui/size")
local _ = require("gettext")
local Screen = require("device").screen

local NotesWidget = require("./widget")


local Notes = WidgetContainer:new {
  name = "notes",
  is_doc_only = false,
  -- is_always_active = true,
  -- modal = true,
  -- stop_events_propagation = true,
  -- keyboard_state = nil,
  -- width = nil,
}

function Notes:init()
  logger.dbg("Notes:init");

  self.layout = {}
  self.width = self.width or math.floor(math.min(Screen:getWidth(), Screen:getHeight()) * 0.9)
  self.name = "Notes";
  self.title_bar = TitleBar:new {
    width = self.width,
    with_bottom_line = true,
    title = _("Notes"),
    bottom_v_padding = 0,
    show_parent = self,
    right_icon = "close",
    close_callback = function()
      UIManager:close(NotesWidget);
      UIManager:close(self.dialog_frame);
      UIManager:setDirty("ui", "full");
    end
  }
  self.dialog_frame = FrameContainer:new {
    radius = Size.radius.window,
    bordersize = Size.border.window,
    padding = 0,
    margin = 0,
    background = Blitbuffer.COLOR_WHITE,
    VerticalGroup:new {
      align = "center",
      self.title_bar,
      NotesWidget,
    }
  }

  NotesWidget.parent = self.dialog_frame[1]
  NotesWidget.parent2 = self.dialog_frame
  self:onDispatcherRegisterActions()

  self.ui.menu:registerToMainMenu(self)
  logger.dbg("***********************Notes:init ***********************************");
end

function Notes:onClose()
  logger.dbg("Notes:onClose");
  
end

function Notes:onNotesStart()
  logger.dbg("Notes starting");
  Input:registerEventAdjustHook(function(self, hook, hook_params)
      NotesWidget:kernelEventListener(hook, hook_params)
    end,
    { name = "Hook Params" });
  UIManager:show(NotesWidget);
  UIManager:show(self.dialog_frame);
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
