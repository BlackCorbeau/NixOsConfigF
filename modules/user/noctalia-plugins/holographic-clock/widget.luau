-- Holographic Clock
-- Rectangular HUD-style digital clock for Noctalia.
-- No network access, external commands, or additional dependencies.

local weekdays = {
    "ВОСКРЕСЕНЬЕ",
    "ПОНЕДЕЛЬНИК",
    "ВТОРНИК",
    "СРЕДА",
    "ЧЕТВЕРГ",
    "ПЯТНИЦА",
    "СУББОТА",
}

local function timezoneOffset()
    local offset = os.date("%z")

    if offset and #offset == 5 then
        return "UTC" .. string.sub(offset, 1, 3)
            .. ":" .. string.sub(offset, 4, 5)
    end

    return "LOCAL TIME"
end

local function separator()
    return ui.separator({
        orientation = "horizontal",
        thickness = 1,
        color = "primary/0.30",
    })
end

local function renderWidget()
    local now = os.date("*t")
    local time = os.date("%H:%M")
    local seconds = os.date("%S")
    local date = string.format(
        "%02d.%02d.%04d",
        now.day,
        now.month,
        now.year
    )

    desktopWidget.render(ui.column({
        width = 390,
        padding = 18,
        gap = 12,

        fill = "surface/0.94",
        radius = 8,
        border = "primary/0.48",
        borderWidth = 1,
    }, {
        -- HUD HEADER
        ui.row({
            align = "center",
            justify = "space_between",
            gap = 8,
        }, {
            ui.label({
                text = "[ CHRONOS / 01 ]",
                fontSize = 10,
                fontWeight = "bold",
                fontFamily = "monospace",
                color = "primary",
            }),

            ui.label({
                text = "SYSTEM ONLINE  /  LIVE",
                fontSize = 8,
                fontWeight = "bold",
                fontFamily = "monospace",
                color = "on_surface_variant",
            }),
        }),

        separator(),

        -- MAIN DIGITAL TIME
        ui.row({
            align = "center",
            justify = "space_between",
            gap = 10,
        }, {
            ui.column({
                gap = 3,
                align = "start",
            }, {
                ui.label({
                    text = "LOCAL SYSTEM TIME",
                    fontSize = 9,
                    fontWeight = "bold",
                    fontFamily = "monospace",
                    color = "on_surface_variant",
                }),

                ui.label({
                    text = time,
                    fontSize = 66,
                    fontWeight = "bold",
                    fontFamily = "monospace",
                    color = "on_surface",
                }),
            }),

            ui.column({
                gap = 2,
                align = "end",
                justify = "center",
                minWidth = 54,
            }, {
                ui.label({
                    text = "SEC",
                    fontSize = 9,
                    fontWeight = "bold",
                    fontFamily = "monospace",
                    color = "on_surface_variant",
                }),

                ui.label({
                    text = seconds,
                    fontSize = 29,
                    fontWeight = "bold",
                    fontFamily = "monospace",
                    color = "primary",
                }),

                ui.label({
                    text = "24H",
                    fontSize = 8,
                    fontWeight = "bold",
                    fontFamily = "monospace",
                    color = "on_surface_variant",
                }),
            }),
        }),

        -- LINEAR SECOND TRACK: deliberately no circular elements.
        ui.progress({
            progress = now.sec / 60,
            width = 354,
            height = 3,
            radius = 1,
            fill = "primary",
            track = "primary/0.12",
        }),

        separator(),

        -- DATE AND TIMEZONE
        ui.row({
            align = "center",
            justify = "space_between",
            gap = 8,
        }, {
            ui.column({
                gap = 3,
                align = "start",
            }, {
                ui.label({
                    text = weekdays[now.wday],
                    fontSize = 11,
                    fontWeight = "bold",
                    fontFamily = "monospace",
                    color = "primary",
                }),

                ui.label({
                    text = date,
                    fontSize = 12,
                    fontFamily = "monospace",
                    color = "on_surface",
                }),
            }),

            ui.column({
                gap = 3,
                align = "end",
            }, {
                ui.label({
                    text = "TIME OFFSET",
                    fontSize = 8,
                    fontWeight = "bold",
                    fontFamily = "monospace",
                    color = "on_surface_variant",
                }),

                ui.label({
                    text = timezoneOffset(),
                    fontSize = 11,
                    fontWeight = "bold",
                    fontFamily = "monospace",
                    color = "primary",
                }),
            }),
        }),

        -- TECHNICAL FOOTER
        ui.row({
            align = "center",
            justify = "space_between",
            gap = 8,
        }, {
            ui.label({
                text = "TEMPORAL INTERFACE",
                fontSize = 8,
                fontFamily = "monospace",
                color = "on_surface_variant",
            }),

            ui.label({
                text = "SYNC / 1 SEC",
                fontSize = 8,
                fontFamily = "monospace",
                color = "on_surface_variant",
            }),
        }),
    }))
end

function update()
    desktopWidget.setWantsSecondTicks(true)
    renderWidget()
end
