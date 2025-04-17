--[[
This plugin provides a Handwritten notes
]]

local logger = require("logger")
local Blitbuffer = require("ffi/blitbuffer")
local Dispatcher = require("dispatcher")
local FocusManager = require("ui/widget/focusmanager")
local FrameContainer = require("ui/widget/container/framecontainer")
local TitleBar = require("ui/widget/titlebar")
local UIManager = require("ui/uimanager")
local Geom = require("ui/geometry")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Widget = require("ui/widget/widget")
local Size = require("ui/size")
local _ = require("gettext")
local Screen = require("device").screen


--[[
-- This is the notes widget which is going to do the drawing
--]]

local NotesWidget = Widget:new {
  -- dimen = Geom:new { w = 0, h = 0 },
  dimen = Geom:new {
    w = Screen:getSize().w * 0.8,
    h = Screen:getSize().h * 0.6,
  }

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
    return
  end

  logger.dbg("NotesWidget:paintTo", x, y);
  local black = Blitbuffer.COLOR_BLACK
  -- logger.dbg("Position", self.parent);
  -- bb:paintRect(self.tx, self.ty, 10, 10, black)
  bb:blitFrom(self.bb, 0, y, -1 * x, 0, self.dimen.w, self.dimen.h)
  logger.dbg("NotesWidget:paintTo dimen: ", self.dimen);
end

function NotesWidget:handleEvent(event)
  logger.dbg("NotesWidget:handleEvent");
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

  local tx = pos.x - self.dimen.x;
  local ty = pos.y - self.dimen.y;
  logger.dbg("Touch: tx", tx, "ty", ty);
  self.bb:paintRect(tx, ty, 10, 10, Blitbuffer.COLOR_WHITE)
  -- local dimen = NotesWidget.parent:getSize();
  -- dimen.x = self.x
  -- dimen.y = self.y
  -- logger.dbg("dimen", dimen);

  -- UIManager:show(NotesWidget);
  -- UIManager:setDirty("ui", dimen);
  --


  UIManager:setDirty(self.parent2, function()
    return "ui", self.parent2.dimen
  end);

  return true
end

local Notes = FocusManager:new {
  is_always_active = true,
  modal = true,
  stop_events_propagation = true,
  keyboard_state = nil,
  width = nil,
}

function Notes:init()
  logger.dbg("Notes:init");

  self.layout = {}
  self.width = self.width or math.floor(math.min(Screen:getWidth(), Screen:getHeight()) * 0.8)
  self.name = "Notes";
  self.title_bar = TitleBar:new {
    width = self.width,
    with_bottom_line = true,
    title = _("Notes"),
    bottom_v_padding = 0,
    show_parent = self,
    right_icon = "close",
    close_callback = function()
      UIManager:close(self.dialog_frame);
      UIManager:close(NotesWidget);
      UIManager:close(self);
      UIManager:setDirty("ui", "full");
    end

  }


  self.dialog_frame = FrameContainer:new {
    radius = Size.radius.window,
    bordersize = Size.border.window,
    padding = 0,
    margin = 10,
    background = Blitbuffer.COLOR_WHITE,
    VerticalGroup:new {
      align = "center",
      self.title_bar,
      NotesWidget,
    }
  }

  -- VerticalSpan:new {
  --   width = Size.span.vertical_large * 2,
  -- },
  NotesWidget.parent = self.dialog_frame[1]
  NotesWidget.parent2 = self.dialog_frame

  logger.dbg("VerticalGroup ", NotesWidget.parent);
  -- logger.dbg("NotesWidget.bb", NotesWidget.bb);
  -- NotesWidget.dimen = Geom:new {
  --   x = self.parent.getSize().x + self.dialog_frame.margin.w,
  --   y = self.parent.dimen.y + self.title_bar.dimen.y,
  --   w = self.parent.dimen.w * 0.8,
  --   h = self.parent.dimen.h - self.title_bar.dimen.h,
  -- }
  NotesWidget.dimen = Geom:new { w = NotesWidget.parent:getSize().w, h = NotesWidget.parent:getSize().h }

  self:onDispatcherRegisterActions()

  self.ui.menu:registerToMainMenu(self)
  logger.dbg("***********************Notes:init ***********************************");
end

function Notes:onClose()
  logger.dbg("Notes:onClose");
end

function Notes:onNotesStart()
  logger.dbg("Notes starting");
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
