--[[
This plugin provides a Handwritten notes
]]

local logger = require("logger")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Dispatcher = require("dispatcher")
local _ = require("gettext")


local Notes = WidgetContainer:new {
  name = "notes",
  is_doc_only = false,
  scale_factor = 1,
}

function Notes:init()
  logger.info("Notes:init");
  self:onDispatcherRegisterActions()

  logger.info(self.ui.menu);
  self.ui.menu:registerToMainMenu(self)
end

function Notes:onNotesStart() 
  logger.info("Notes starting");
end

function Notes:onDispatcherRegisterActions()
    Dispatcher:registerAction("show_notes",
        {category = "none", event = "NotesStart", title = _("Notes"), device = true})
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
