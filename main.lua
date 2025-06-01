--[[
This plugin provides a Handwritten notes
]]

local logger = require("logger")
local Blitbuffer = require("ffi/blitbuffer")
local ButtonDialog = require("ui/widget/buttondialog")
local Dispatcher = require("dispatcher")
local FrameContainer = require("ui/widget/container/framecontainer")
local Input = require("device").input
local PathChooser = require("ui/widget/pathchooser")
local TitleBar = require("ui/widget/titlebar")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local IconButton = require("ui/widget/iconbutton")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Size = require("ui/size")
local _ = require("gettext")
local Screen = require("device").screen

local NotesWidget = require("./widget")
local InputListener = require("./inputlistener")

---@class Notes
---@field margin int
---@field notesWidget NotesWidget
---@field title_bar TitleBar
---@field currentPath string

---@type Notes
local Notes = WidgetContainer:new {
  name = "notes",
  is_doc_only = false,
}

function Notes:init()
  logger.dbg("Notes:init");
  ---@type NotesWidget
  self.notesWidget = NotesWidget:new();
  self.margin = 10;
  self.debug_plugin = G_reader_settings:readSetting("notes_plugin_debug", false)
  G_reader_settings:saveSetting("notes_plugin_debug", self.debug_plugin)

  self.layout = {}
  self.width = self.width or math.floor(math.min(Screen:getWidth(), Screen:getHeight()) - self.margin * 2)
  self.name = "Notes";
  self.title_bar = TitleBar:new {
    width = self.width - Size.border.window * 4,
    with_bottom_line = true,
    title = _("Notes " .. self.notesWidget:getPageName()),
    bottom_v_padding = 0,
    show_parent = self,
    right_icon = "close",
    left_icon = "appbar.menu",
    left_icon_tap_callback = function() self:showMenu() end,
    close_callback = function()
      self:onClose();
    end
  }

  local options = HorizontalGroup:new {
    IconButton:new {
      height = 50,
      icon = "chevron.left",
      callback = function()
        self.notesWidget:prevPage();
        self.title_bar:setTitle(_("Notes " .. self.notesWidget:getPageName()));
      end
    },
    IconButton:new {
      height = 50,
      icon = "chevron.right",
      callback = function()
        self.notesWidget:nextPage();
        self.title_bar:setTitle(_("Notes " .. self.notesWidget:getPageName()));
      end
    }
  }


  self.dialog_frame = FrameContainer:new {
    radius = Size.radius.window,
    bordersize = Size.border.window,
    width = self.width + Size.border.window * 2,
    padding = 0,
    margin = self.margin,
    background = Blitbuffer.COLOR_WHITE,
    VerticalGroup:new {
      align = "left",
      self.title_bar,
      options,
      self.notesWidget,
    }
  }

  self:onDispatcherRegisterActions()

  self.ui.menu:registerToMainMenu(self)

  Input:registerEventAdjustHook(
    function(input, event, hook_params)
      InputListener:eventAdjustmentHook(input, event, hook_params)
    end,
    { name = "InputListener Hook Params" });

  InputListener:setListener(function(event, hook_params)
    self.notesWidget:touchEventListener(event, hook_params)
  end);
  logger.dbg("Notes:init registerd EventAdjustHook");

  logger.dbg("***********************Notes:init ***********************************");
end

function Notes:onClose()
  logger.dbg("Notes:onClose");
  self.isRunning = false
  self.notesWidget.isRunning = false
  UIManager:close(self.notesWidget);
  UIManager:close(self.dialog_frame);
  UIManager:setDirty("ui", "full");
  InputListener:cleanupGestureDetector();
end

function Notes:onNotesStart()
  self.isRunning = true
  self.notesWidget.isRunning = true
  UIManager:show(self.notesWidget);
  UIManager:show(self.dialog_frame);
  UIManager:setDirty("ui", "full");
  InputListener:setupGestureDetector();
end

function Notes:onRunTest()
  logger.info("Running Tests");
  self.isRunning = true
  self.notesWidget.isRunning = true
  -- self:onNotesStart();
  InputListener:runTest(Input, {});
end

function Notes:onDispatcherRegisterActions()
  Dispatcher:registerAction("show_notes",
    { category = "none", event = "NotesStart", title = _("Show Notes"), general = true })

  Dispatcher:registerAction("run_notes_test",
    { category = "none", event = "RunTest", title = _("Run Notes Test"), general = true })
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
  if self.debug_plugin then
    menu_items.debugnotes = {
      text = _("Test Notes Plugin"),
      callback = function()
        self:onRunTest()
      end,
    }
  end
end

function Notes:showMenu()
  local dialog
  local buttons = {
    {
      text = _("Save"),
      callback = function()
        UIManager:close(dialog)
        logger.dbg("Notes: Saving");
        if self.currentPath then
          self.notesWidget:saveToDir(self.currentPath);
        else
          self.notesWidget.isRunning = false;
          logger.dbg("Opening pathchooser");
          local path_chooser = PathChooser:new {
            select_file = false,
            -- path = "/",
            onConfirm = function(dirPath)
              logger.info("Selected folder ", dirPath);
              self.currentPath = dirPath;
              self.notesWidget.isRunning = true;
              self.notesWidget:saveToDir(self.currentPath);
            end,
            onCancel = function()
              self.notesWidget.isRunning = true;
            end
          }
          UIManager:show(path_chooser)
        end
      end,
    }
  }

  if self.debug_plugin then
    table.insert(buttons, {
      text = _("Test"),
      callback = function()
        UIManager:close(dialog)
        self:onRunTest();
      end
    }
    )
  end

  dialog = ButtonDialog:new {
    shrink_unneeded_width = true,
    buttons = { buttons },
    anchor = function()
      return self.title_bar.left_button.image.dimen
    end,
    modal = true,
  }
  UIManager:show(dialog)
end

return Notes
