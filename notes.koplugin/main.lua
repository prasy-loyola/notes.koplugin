--[[
This plugin provides a Handwritten notes
]]

local logger = require("logger")
local Blitbuffer = require("ffi/blitbuffer")
local Dispatcher = require("dispatcher")
local FrameContainer = require("ui/widget/container/framecontainer")
local Input = require("device").input
local TitleBar = require("ui/widget/titlebar")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Size = require("ui/size")
local _ = require("gettext")
local Screen = require("device").screen

local NotesWidget = require("./widget")
local InputListener = require("./inputlistener")

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
  self.margin = 10;

  self.layout = {}
  self.width = self.width or math.floor(math.min(Screen:getWidth(), Screen:getHeight()) - self.margin * 2)
  self.name = "Notes";
  self.title_bar = TitleBar:new {
    width = self.width - Size.border.window * 4,
    with_bottom_line = true,
    title = _("Notes"),
    bottom_v_padding = 0,
    show_parent = self,
    right_icon = "close",
    left_icon = "",
    close_callback = function()
      self.isRunning = false
      NotesWidget.isRunning = false
      UIManager:close(NotesWidget);
      UIManager:close(self.dialog_frame);
      UIManager:setDirty("ui", "full");
    end
  }
  self.dialog_frame = FrameContainer:new {
    radius = Size.radius.window,
    bordersize = Size.border.window,
    width = self.width + Size.border.window * 2,
    padding = 0,
    margin = self.margin,
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

  Input:registerEventAdjustHook(
    function(input, event, hook_params)
      InputListener:eventAdjustmentHook(input, event, hook_params)
    end,
    { name = "InputListener Hook Params" });

  InputListener:setListener(function(event, hook_params) NotesWidget:touchEventListener(event, hook_params) end);
  logger.dbg("Notes:init registerd EventAdjustHook");

  logger.dbg("***********************Notes:init ***********************************");
end

function Notes:onClose()
  self.isRunning = false
  logger.dbg("Notes:onClose");
end

function Notes:onNotesStart()
  self.isRunning = true
  NotesWidget.isRunning = true
  UIManager:show(NotesWidget);
  UIManager:show(self.dialog_frame);
  UIManager:setDirty("ui", "full");
end

function Notes:onDispatcherRegisterActions()
  Dispatcher:registerAction("show_notes",
    { category = "none", event = "NotesStart", title = _("Show Notes"), general = true })
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
