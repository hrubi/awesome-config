-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
awful.rules = require("awful.rules")
require("awful.autofocus")
-- Widget and layout library
local wibox = require("wibox")
-- Theme handling library
local beautiful = require("beautiful")
-- Notification library
local naughty = require("naughty")
local menubar = require("menubar")
-- Vicious widgets
vicious = require("vicious")

-- {{{ Set locale
os.setlocale(os.getenv("LC_TIME"), "time")
-- }}}

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Oops, there were errors during startup!",
                     text = awesome.startup_errors })
end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Oops, an error happened!",
                         text = err })
        in_error = false
    end)
end
-- }}}

-- {{{ Variable definitions
-- Themes define colours, icons, and wallpapers
beautiful.init(awful.util.getdir("config") .. "/themes/current/theme.lua")

-- Source local configuration and supply defaults
success, localconfig = pcall(function()
        return dofile(awful.util.getdir("config") .. "/rc_local.lua")
    end)
if not success or not localconfig then
    localconfig = {}
end

terminal   = localconfig.terminal  or "urxvtc"
browser    = localconfig.browser   or "firefox"
moc        = localconfig.moc       or terminal .. " -name MOC -e mocp"
ncmpc      = localconfig.ncmpc     or terminal .. " -name NCMPC -e ncmpc"
lock       = localconfig.lock      or "xlock"
editor     = os.getenv("EDITOR")   or "vim"
editor_cmd = terminal .. " -e " .. editor

laptop     = localconfig.laptop    or false

-- Modifier keys
modkey = "Mod4"
altkey = "Mod1"

-- Table of layouts to cover with awful.layout.inc, order matters.
local layouts =
{
    awful.layout.suit.max,
    awful.layout.suit.tile,
    awful.layout.suit.fair,
    awful.layout.suit.floating,
}
-- }}}

-- {{{ Helper function for listing directory
function scandir(directory)
    local i, t, popen = 0, {}, io.popen
    for filename in popen('ls "'..directory..'"/*'):lines() do
        i = i + 1
        t[i] = filename
    end
    return t
end
-- }}}

-- {{{ Wallpaper
if beautiful.wallpaper then
    for s = 1, screen.count() do
        if os.execute("test -d " .. beautiful.wallpaper) then
            -- Cycle through wallpapers
            local update_interval = beautiful.wallpaper_update or 600
            local timer = timer({ timeout =  update_interval })
            files = scandir(beautiful.wallpaper)
            update_wp = function()
                local file = files[math.random(#files)]
                gears.wallpaper.maximized(file, s, true)
            end
            timer:connect_signal("timeout", update_wp)
            timer:emit_signal("timeout")
            timer:start()
        else
            -- Set single wallpaper
            gears.wallpaper.maximized(beautiful.wallpaper, s, true)
        end

    end
end
-- }}}

-- {{{ Tags
-- Define a tag table which hold all screen tags.
tags = {}
for s = 1, screen.count() do
    -- Each screen has its own tag table.
    tags[s] = awful.tag({ 1, 2, 3, 4, 5, 6 }, s, layouts[1])
end
-- }}}

-- {{{ Menu
-- Create a laucher widget and a main menu
myawesomemenu = {
   { "manual", terminal .. " -e man awesome" },
   { "edit config", editor_cmd .. " " .. awesome.conffile },
   { "restart", awesome.restart },
   { "quit", awesome.quit }
}

mymainmenu = awful.menu({ items = { { "awesome", myawesomemenu, beautiful.awesome_icon },
                                    { "open terminal", terminal }
                                  }
                        })

mylauncher = awful.widget.launcher({ image = beautiful.awesome_icon,
                                     menu = mymainmenu })

-- Menubar configuration
menubar.utils.terminal = terminal -- Set the terminal for applications that require it
-- }}}

-- {{{ Wibox
-- Field separator
separator = wibox.widget.textbox(" ")

-- Create a textclock widget
mytextclock = awful.widget.textclock()
volume_control = localconfig.volume_control or "Master"
mytextclock:buttons(awful.util.table.join(
    -- volume binding on wheel
    awful.button({ }, 4, function () awful.util.spawn("amixer -q set " .. volume_control .. " '5%+'") end),
    awful.button({ }, 5, function () awful.util.spawn("amixer -q set " .. volume_control .. " '5%-'") end),

    -- player binding
    awful.button({ }, 3, function () awful.util.spawn("mocp -G") end),
    awful.button({ "Control" }, 4, function () awful.util.spawn("mocp -f") end),
    awful.button({ "Control" }, 5, function () awful.util.spawn("mocp -r") end)
))

-- Laptop specific widgets
if localconfig.laptop then
    -- Battery widget(s)
    vicious.cache(vicious.widgets.bat)
    -- percentage progressbar
    battery_graph = awful.widget.progressbar()
    battery_graph:set_width(8)
    battery_graph:set_height(10)
    battery_graph:set_vertical(true)
    battery_graph:set_background_color(beautiful.bg_normal)
    battery_graph:set_border_color(beautiful.fg_normal)
    vicious.register(battery_graph, vicious.widgets.bat,
        function(widget, args)
            local percent = args[2]
            if percent > 50 then
                widget:set_color("#4FF00")
            elseif percent > 20 then
                widget:set_color("#FFBB00")
            else
                widget:set_color("#FF1200")
            end
            return percent
        end,
        60, "BAT0")
    -- percentage text
    battery_percent = wibox.widget.textbox()
    vicious.register(battery_percent, vicious.widgets.bat, "$2%", 60, "BAT0")
    -- status symbol (charging, full, ..)
    battery_state = wibox.widget.textbox()
    vicious.register(battery_state, vicious.widgets.bat, "$1", 60, "BAT0")
    -- tooltip with remaining time
    battery_time_t = awful.tooltip({
        objects = { battery_state, battery_graph, battery_percent }
    })
    vicious.register(battery_time_t.widget, vicious.widgets.bat,
        function(widget, args)
            local state_name
            local state = args[1]
            local percent = args[2] .. "%"
            local time = ""
            if state == "↯" then
                state_name = "Full"
            elseif state == "⌁" then
                state_name = "Unknown"
            elseif state == "-" then
                state_name = "Discharging"
                time = args[3]
            elseif state == "+" then
                state_name = "Charging"
                time = args[3]
            end
            if time then
                return state_name .. " " .. percent .. "\n" .. "Remaining " .. time
            else
                return state_name .. " " .. percent
            end
        end,
    60, "BAT0")

    -- WiFi widget(s)
    vicious.cache(vicious.widgets.wifi)

    wifi_link = wibox.widget.textbox()
    vicious.register(wifi_link, vicious.widgets.wifi,
        function(widget, args)
            if args["{ssid}"] == "N/A" then
                return ""
            else
                return args["{ssid}"] .. ":" .. args["{linp}"] .. "% "
            end
        end,
        10, "wifi0")

    -- tooltip with complete wifi info
    wifi_info = awful.tooltip({
        objects = { wifi_link }
    })
    vicious.register(wifi_info.widget, vicious.widgets.wifi,
        function(widget, args)
            return "SSID:         " .. args["{ssid}"] .. "\n" ..
                   "Bit Rate:     " .. args["{rate}"] .. "\n" ..
                   "Signal level: " .. args["{sign}"] .. "\n" ..
                   "Mode:         " .. args["{mode}"]
        end,
        10, "wifi0")
end

-- Create a wibox for each screen and add it
mywibox = {}
mypromptbox = {}
mylayoutbox = {}
mytaglist = {}
mytaglist.buttons = awful.util.table.join(
                    awful.button({ }, 1, awful.tag.viewonly),
                    awful.button({ modkey }, 1, awful.client.movetotag),
                    awful.button({ }, 3, awful.tag.viewtoggle),
                    awful.button({ modkey }, 3, awful.client.toggletag),
                    awful.button({ }, 4, function(t) awful.tag.viewnext(awful.tag.getscreen(t)) end),
                    awful.button({ }, 5, function(t) awful.tag.viewprev(awful.tag.getscreen(t)) end)
                    )
mytasklist = {}
mytasklist.buttons = awful.util.table.join(
                     awful.button({ }, 1, function (c)
                                              if c == client.focus then
                                                  c.minimized = true
                                              else
                                                  -- Without this, the following
                                                  -- :isvisible() makes no sense
                                                  c.minimized = false
                                                  if not c:isvisible() then
                                                      awful.tag.viewonly(c:tags()[1])
                                                  end
                                                  -- This will also un-minimize
                                                  -- the client, if needed
                                                  client.focus = c
                                                  c:raise()
                                              end
                                          end),
                     awful.button({ }, 3, function ()
                                              if instance then
                                                  instance:hide()
                                                  instance = nil
                                              else
                                                  instance = awful.menu.clients({ width=250 })
                                              end
                                          end),
                     awful.button({ }, 4, function ()
                                              awful.client.focus.byidx(1)
                                              if client.focus then client.focus:raise() end
                                          end),
                     awful.button({ }, 5, function ()
                                              awful.client.focus.byidx(-1)
                                              if client.focus then client.focus:raise() end
                                          end))

for s = 1, screen.count() do
    -- Create a promptbox for each screen
    mypromptbox[s] = awful.widget.prompt()
    -- Create an imagebox widget which will contains an icon indicating which layout we're using.
    -- We need one layoutbox per screen.
    mylayoutbox[s] = awful.widget.layoutbox(s)
    mylayoutbox[s]:buttons(awful.util.table.join(
                           awful.button({ }, 1, function () awful.layout.inc(layouts, 1) end),
                           awful.button({ }, 3, function () awful.layout.inc(layouts, -1) end),
                           awful.button({ }, 4, function () awful.layout.inc(layouts, 1) end),
                           awful.button({ }, 5, function () awful.layout.inc(layouts, -1) end)))
    -- Create a taglist widget
    mytaglist[s] = awful.widget.taglist(s, awful.widget.taglist.filter.all, mytaglist.buttons)

    -- Create a tasklist widget
    mytasklist[s] = awful.widget.tasklist(s, awful.widget.tasklist.filter.currenttags, mytasklist.buttons)

    -- Create the wibox
    mywibox[s] = awful.wibox({ position = "top", screen = s })

    -- Widgets that are aligned to the left
    local left_layout = wibox.layout.fixed.horizontal()
    left_layout:add(mylauncher)
    left_layout:add(mytaglist[s])
    left_layout:add(mypromptbox[s])

    -- Widgets that are aligned to the right
    local right_layout = wibox.layout.fixed.horizontal()
    if s == 1 then right_layout:add(wibox.widget.systray()) end
    right_layout:add(mytextclock)
    if localconfig.laptop then
        right_layout:add(wifi_link)
        right_layout:add(battery_state)
        right_layout:add(battery_graph)
        right_layout:add(battery_percent)
    end
    right_layout:add(mylayoutbox[s])

    -- Now bring it all together (with the tasklist in the middle)
    local layout = wibox.layout.align.horizontal()
    layout:set_left(left_layout)
    layout:set_middle(mytasklist[s])
    layout:set_right(right_layout)

    mywibox[s]:set_widget(layout)
end
-- }}}

-- {{{ Key bindings
globalkeys = awful.util.table.join(
    awful.key({ altkey,           }, "Tab",
        function ()
            awful.client.focus.byidx( 1)
            if client.focus then client.focus:raise() end
        end),
    awful.key({ altkey, "Shift"   }, "Tab",
        function ()
            awful.client.focus.byidx(-1)
            if client.focus then client.focus:raise() end
        end),
    awful.key({ modkey,           }, "m", function () mymainmenu:show() end),

    -- Layout manipulation
    awful.key({ altkey,           }, "Return", function () awful.client.swap.byidx(  1)    end),
    awful.key({ altkey, "Shift"   }, "Return", function () awful.client.swap.byidx( -1)    end),
    awful.key({ altkey,           }, ".", function () awful.screen.focus_relative( 1) end),
    awful.key({ altkey,           }, ",", function () awful.screen.focus_relative(-1) end),
    awful.key({ modkey,           }, "u", awful.client.urgent.jumpto),

    -- Standard program
    awful.key({ altkey, "Control" }, "Return", function () awful.util.spawn(terminal) end),
    awful.key({ altkey, "Control" }, "d",      function () awful.util.spawn(browser) end),
    awful.key({ altkey, "Control" }, "m",      function () awful.util.spawn(moc) end),
    awful.key({ altkey, "Control" }, "n",      function () awful.util.spawn(ncmpc) end),
    awful.key({ altkey, "Control" }, "l",      function () awful.util.spawn(lock) end),

    awful.key({ modkey, "Control" }, "r", awesome.restart),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit),

    awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05)    end),
    awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05)    end),
    awful.key({ modkey, "Shift"   }, "h",     function () awful.tag.incnmaster( 1)      end),
    awful.key({ modkey, "Shift"   }, "l",     function () awful.tag.incnmaster(-1)      end),
    awful.key({ modkey, "Control" }, "h",     function () awful.tag.incncol( 1)         end),
    awful.key({ modkey, "Control" }, "l",     function () awful.tag.incncol(-1)         end),
    awful.key({ modkey,           }, "space", function () awful.layout.inc(layouts,  1) end),
    awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(layouts, -1) end),

    -- Set layouts
    awful.key({ modkey, "Control" }, "m",     function () awful.layout.set(awful.layout.suit.max)            end),
    awful.key({ modkey, "Control" }, "d",     function () awful.layout.set(awful.layout.suit.tile)           end),
    awful.key({ modkey, "Control" }, "f",     function () awful.layout.set(awful.layout.suit.floating)       end),
    awful.key({ modkey, "Control" }, "g",     function () awful.layout.set(awful.layout.suit.fair)           end),
    -- Hide/show wibox
    awful.key({ modkey, "Control" }, "b",
                function ()
                    mywibox[mouse.screen].visible = not mywibox[mouse.screen].visible
                end),

    awful.key({ modkey, "Control" }, "n", awful.client.restore),

    -- Prompt
    awful.key({ altkey, "Control" }, "x",     function () mypromptbox[mouse.screen]:run() end),

    awful.key({ modkey }, "x",
              function ()
                  awful.prompt.run({ prompt = "Run Lua code: " },
                  mypromptbox[mouse.screen].widget,
                  awful.util.eval, nil,
                  awful.util.getdir("cache") .. "/history_eval")
              end)
)

clientkeys = awful.util.table.join(
    awful.key({ modkey, "Shift"   }, "f",      function (c) c.fullscreen = not c.fullscreen  end),
    awful.key({ altkey,           }, "Escape", function (c) c:kill()                         end),
    awful.key({ modkey,           }, "f",      awful.client.floating.toggle                     ),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end),
    awful.key({ modkey,           }, ",",      awful.client.movetoscreen                        ),
    awful.key({ modkey,           }, ".",      awful.client.movetoscreen                        ),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end),

    awful.key({ modkey,           }, "n",
        function (c)
            -- The client currently has the input focus, so it cannot be
            -- minimized, since minimized clients can't have the focus.
            c.minimized = true
        end),
    awful.key({ modkey,           }, "m",
        function (c)
            c.maximized_horizontal = not c.maximized_horizontal
            c.maximized_vertical   = not c.maximized_vertical
        end)
)

-- Compute the maximum number of digit we need, limited to 9
keynumber = 0
for s = 1, screen.count() do
   keynumber = math.min(12, math.max(#tags[s], keynumber))
end

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it works on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, keynumber do
    globalkeys = awful.util.table.join(globalkeys,
        awful.key({ altkey }, "F" .. i,
                  function ()
                        local screen = mouse.screen
                        if tags[screen][i] then
                            awful.tag.viewonly(tags[screen][i])
                        end
                  end),
        awful.key({ altkey, "Shift" }, "F" .. i,
                  function ()
                      local screen = mouse.screen
                      if tags[screen][i] then
                          awful.tag.viewtoggle(tags[screen][i])
                      end
                  end),
        awful.key({ modkey }, "F" .. i,
                  function ()
                      if client.focus and tags[client.focus.screen][i] then
                          awful.client.movetotag(tags[client.focus.screen][i])
                      end
                  end),
        awful.key({ modkey, "Shift" }, "F" .. i,
                  function ()
                      if client.focus and tags[client.focus.screen][i] then
                          awful.client.toggletag(tags[client.focus.screen][i])
                      end
                  end))
end

clientbuttons = awful.util.table.join(
    awful.button({ }, 1, function (c) client.focus = c; c:raise() end),
    awful.button({ altkey }, 1, awful.mouse.client.move),
    awful.button({ altkey }, 3, awful.mouse.client.resize))

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
awful.rules.rules = {
    -- All clients will match this rule.
    { rule = { },
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
                     focus = awful.client.focus.filter,
                     keys = clientkeys,
                     buttons = clientbuttons } },
    { rule = { class = "MPlayer" },
      properties = { floating = true } },
    { rule = { class = "pinentry" },
      properties = { floating = true } },
    { rule = { class = "gimp" },
      properties = { floating = true } },
    -- Set Firefox to always map on tags number 2 of screen 1.
    -- { rule = { class = "Firefox" },
    --   properties = { tag = tags[1][2] } },
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c, startup)
    -- Enable sloppy focus
    c:connect_signal("mouse::enter", function(c)
        if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier
            and awful.client.focus.filter(c) then
            client.focus = c
        end
    end)

    if not startup then
        -- Set the windows at the slave,
        -- i.e. put it at the end of others instead of setting it master.
        -- awful.client.setslave(c)

        -- Put windows in a smart way, only if they does not set an initial position.
        if not c.size_hints.user_position and not c.size_hints.program_position then
            awful.placement.no_overlap(c)
            awful.placement.no_offscreen(c)
        end
    end

    local titlebars_enabled = false
    if titlebars_enabled and (c.type == "normal" or c.type == "dialog") then
        -- Widgets that are aligned to the left
        local left_layout = wibox.layout.fixed.horizontal()
        left_layout:add(awful.titlebar.widget.iconwidget(c))

        -- Widgets that are aligned to the right
        local right_layout = wibox.layout.fixed.horizontal()
        right_layout:add(awful.titlebar.widget.floatingbutton(c))
        right_layout:add(awful.titlebar.widget.maximizedbutton(c))
        right_layout:add(awful.titlebar.widget.stickybutton(c))
        right_layout:add(awful.titlebar.widget.ontopbutton(c))
        right_layout:add(awful.titlebar.widget.closebutton(c))

        -- The title goes in the middle
        local title = awful.titlebar.widget.titlewidget(c)
        title:buttons(awful.util.table.join(
                awful.button({ }, 1, function()
                    client.focus = c
                    c:raise()
                    awful.mouse.client.move(c)
                end),
                awful.button({ }, 3, function()
                    client.focus = c
                    c:raise()
                    awful.mouse.client.resize(c)
                end)
                ))

        -- Now bring it all together
        local layout = wibox.layout.align.horizontal()
        layout:set_left(left_layout)
        layout:set_right(right_layout)
        layout:set_middle(title)

        awful.titlebar(c):set_widget(layout)
    end
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
-- }}}
