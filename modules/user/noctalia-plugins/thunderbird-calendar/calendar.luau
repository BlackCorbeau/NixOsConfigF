-- Thunderbird Calendar
-- Noctalia desktop widget: a month grid with the selected day's events.
--
-- Events come from Thunderbird's own synchronized calendar cache through a
-- small read-only Python helper. Noctalia never talks to CalDAV and stores no
-- credentials; Thunderbird remains the only calendar client.

local REFRESH_SECONDS = math.max(
    30,
    tonumber(noctalia.getConfig("refresh_seconds")) or 120
)

local START_MONDAY = noctalia.getConfig("start_monday")
if START_MONDAY == nil then
    START_MONDAY = true
end

local WEEKDAYS_MONDAY = { "ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ", "ВС" }
local WEEKDAYS_SUNDAY = { "ВС", "ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ" }

local WEEKDAY_FULL = {
    "воскресенье",
    "понедельник",
    "вторник",
    "среда",
    "четверг",
    "пятница",
    "суббота",
}

local MONTH_NOMINATIVE = {
    "Январь",
    "Февраль",
    "Март",
    "Апрель",
    "Май",
    "Июнь",
    "Июль",
    "Август",
    "Сентябрь",
    "Октябрь",
    "Ноябрь",
    "Декабрь",
}

local MONTH_GENITIVE = {
    "января",
    "февраля",
    "марта",
    "апреля",
    "мая",
    "июня",
    "июля",
    "августа",
    "сентября",
    "октября",
    "ноября",
    "декабря",
}

-- =========================================================
-- STATE
-- =========================================================

-- Keep the widget's outer width constant while the events panel is hidden.
-- 278 (calendar) + 306 (events panel) + 12 (gap) + 20 (outer padding).
-- Otherwise Noctalia recalculates the anchored widget position when a day
-- is selected, making the whole calendar appear to jump to the left.
local WIDGET_WIDTH = 278 + 306 + 12 + 20

local events = {}
local byDay = {}

local nowTable = os.date("*t")
local viewYear = nowTable.year
local viewMonth = nowTable.month

local function dayKey(year, month, day)
    return string.format("%04d-%02d-%02d", year, month, day)
end

-- Interaction state: clicking a day opens its events panel; clicking the
-- selected day again closes it, clicking another day switches the selection.
local selectedKey = nil

local function isSelected(key)
    return selectedKey == key
end

local function toggleSelection(key)
    if selectedKey == key then
        selectedKey = nil
    else
        selectedKey = key
    end

    render()
end

local loading = false
local lastError = nil
local lastRefreshAttempt = 0
local lastUpdated = nil

-- =========================================================
-- DATA
-- =========================================================

local function midnight(seconds)
    local t = os.date("*t", seconds)
    return os.time({
        year = t.year,
        month = t.month,
        day = t.day,
        hour = 0,
        min = 0,
        sec = 0,
    })
end

local function nextMidnight(seconds)
    local t = os.date("*t", seconds)
    return os.time({
        year = t.year,
        month = t.month,
        day = t.day + 1,
        hour = 0,
        min = 0,
        sec = 0,
    })
end

local function sortEvents(list)
    table.sort(list, function(a, b)
        local aStart = tonumber(a.startMs) or 0
        local bStart = tonumber(b.startMs) or 0
        if aStart == bStart then
            return tostring(a.name or "") < tostring(b.name or "")
        end
        return aStart < bStart
    end)
end

local function rebuildIndex()
    byDay = {}

    for _, event in ipairs(events) do
        local startMs = tonumber(event.startMs) or 0
        local endMs = tonumber(event.endMs) or startMs
        if endMs <= startMs then
            endMs = startMs + 60000
        end

        local cursor = midnight(math.floor(startMs / 1000))
        local guard = 0

        while cursor * 1000 < endMs and guard < 62 do
            local t = os.date("*t", cursor)
            local key = dayKey(t.year, t.month, t.day)

            if byDay[key] == nil then
                byDay[key] = {}
            end

            table.insert(byDay[key], event)

            cursor = nextMidnight(cursor)
            guard = guard + 1
        end
    end

    for _, list in pairs(byDay) do
        sortEvents(list)
    end
end

local function eventsForDay(year, month, day)
    return byDay[dayKey(year, month, day)] or {}
end

local function refresh()
    if loading then
        return
    end

    local pluginDir = noctalia.pluginDir()
    if pluginDir == nil then
        lastError = "Плагин не найден"
        render()
        return
    end

    loading = true
    lastRefreshAttempt = os.time()
    render()

    local accepted = noctalia.runAsync({
        "python3",
        pluginDir .. "/thunderbird-calendar.py",
    }, function(result)
        loading = false
        lastUpdated = os.time()

        if result == nil then
            lastError = "Нет ответа от python3"
            noctalia.log("[Thunderbird Calendar] empty runAsync result")
            render()
            return
        end

        if tonumber(result.exitCode) ~= 0 then
            lastError = "Не удалось прочитать кэш Thunderbird"
            noctalia.log(
                "[Thunderbird Calendar] helper failed: "
                    .. tostring(result.stderr or "")
            )
            render()
            return
        end

        local data, decodeError = noctalia.json.decode(result.stdout or "")
        if type(data) ~= "table" then
            lastError = "Ошибка разбора данных календаря"
            noctalia.log(
                "[Thunderbird Calendar] JSON error: "
                    .. tostring(decodeError)
            )
            render()
            return
        end

        if data.error then
            lastError = "Кэш Thunderbird недоступен"
            noctalia.log(
                "[Thunderbird Calendar] bridge error: "
                    .. tostring(data.error)
            )
            render()
            return
        end

        events = type(data.events) == "table" and data.events or {}
        lastError = nil
        rebuildIndex()

        noctalia.log(
            "[Thunderbird Calendar] loaded "
                .. tostring(#events)
                .. " events"
        )

        render()
    end)

    if accepted ~= true then
        loading = false
        lastError = "Не удалось запустить python3"
        noctalia.log("[Thunderbird Calendar] runAsync rejected")
        render()
    end
end

-- =========================================================
-- UI HELPERS
-- =========================================================

local function isValidHexColor(value)
    if type(value) ~= "string" then
        return false
    end

    return value:match("^#%x%x%x%x%x%x$") ~= nil
        or value:match("^#%x%x%x%x%x%x%x%x$") ~= nil
end

local function daysInMonth(year, month)
    return os.date("*t", os.time({
        year = year,
        month = month + 1,
        day = 0,
        hour = 12,
        min = 0,
        sec = 0,
    })).day
end

local function currentMonthOffset(firstDayTable)
    -- Lua wday: Sunday = 1 ... Saturday = 7.
    if START_MONDAY then
        return (firstDayTable.wday + 5) % 7
    end
    return firstDayTable.wday - 1
end

local function shiftMonth(delta)
    local month = viewMonth + delta
    local year = viewYear

    while month < 1 do
        month = month + 12
        year = year - 1
    end

    while month > 12 do
        month = month - 12
        year = year + 1
    end

    viewYear = year
    viewMonth = month

    if selectedKey ~= nil then
        local selectedDay = tonumber(selectedKey:sub(9, 10)) or 1
        selectedDay = math.min(selectedDay, daysInMonth(year, month))
        selectedKey = dayKey(year, month, selectedDay)
    end

    render()
end

local function goToday()
    local now = os.date("*t")
    viewYear = now.year
    viewMonth = now.month

    if selectedKey ~= nil then
        selectedKey = dayKey(now.year, now.month, now.day)
    end

    render()
end

-- =========================================================
-- DAY CELL
-- =========================================================

local function eventDots(count, expanded)
    local dots = {}

    for index = 1, math.min(count, 3) do
        dots[index] = ui.box({
            width = 3,
            height = 3,
            radius = 2,
            fill = expanded and "on_primary" or "primary",
        })
    end

    return ui.row({
        height = 5,
        gap = 2,
        align = "center",
        justify = "center",
    }, dots)
end

local function dayCell(year, month, day, inViewMonth, isToday)
    local key = dayKey(year, month, day)
    local count = #eventsForDay(year, month, day)

    local expanded = isSelected(key)

    local fill = "#00000000"
    local border = "#00000000"
    local borderWidth = 0
    local numberColor = "on_surface"

    if expanded then
        fill = "primary"
        numberColor = "on_primary"
    elseif isToday then
        fill = "primary/0.12"
        border = "primary"
        borderWidth = 1
        numberColor = "primary"
    elseif not inViewMonth then
        numberColor = "on_surface_variant/0.45"
    end

    return ui.column({
        key = "day-" .. key,
        width = 34,
        height = 34,
        padding = 2,
        gap = 1,
        radius = 8,
        align = "center",
        justify = "center",
        fill = fill,
        border = border,
        borderWidth = borderWidth,
        onClick = function()
            if not inViewMonth and selectedKey ~= key then
                viewYear = year
                viewMonth = month
            end
            toggleSelection(key)
        end,
    }, {
        ui.label({
            text = tostring(day),
            fontSize = 11,
            fontWeight = expanded and "bold" or "medium",
            color = numberColor,
        }),

        eventDots(count, expanded),
    })
end

-- =========================================================
-- EVENT LIST
-- =========================================================

local function metaRow(event)
    local children = {}

    if isValidHexColor(event.color) then
        table.insert(children, ui.box({
            width = 6,
            height = 6,
            radius = 3,
            fill = event.color,
        }))
    end

    table.insert(children, ui.label({
        text = tostring(event.calendar or ""),
        fontSize = 9,
        color = "on_surface_variant",
        maxLines = 1,
        flexGrow = 1,
    }))

    return ui.row({
        align = "center",
        gap = 4,
    }, children)
end

local function eventRow(event, dayStartMs, dayEndMs)
    local eventStart = tonumber(event.startMs) or 0
    local eventEnd = tonumber(event.endMs) or eventStart

    if eventEnd <= eventStart then
        eventEnd = eventStart + 60000
    end

    local visibleStart = math.max(eventStart, dayStartMs)
    local visibleEnd = math.min(eventEnd, dayEndMs)
    local allDay = event.allDay == true
        or (eventStart <= dayStartMs and eventEnd >= dayEndMs)

    local timeMain = os.date("%H:%M", math.floor(visibleStart / 1000))
    local timeSub = ""

    if allDay then
        timeMain = "весь"
        timeSub = "день"
    elseif eventEnd > dayEndMs then
        timeMain = os.date("%H:%M", math.floor(visibleStart / 1000))
        timeSub = "…"
    elseif eventStart < dayStartMs then
        timeMain = "…"
        timeSub = os.date("%H:%M", math.floor(visibleEnd / 1000))
    else
        timeSub = os.date("%H:%M", math.floor(visibleEnd / 1000))
    end

    return ui.row({
        key = "event-" .. tostring(event.id or eventStart),
        gap = 8,
        padding = 7,
        align = "center",
        fill = "surface/0.5",
        radius = 8,
    }, {
        ui.column({
            width = 40,
            gap = 0,
            align = "start",
        }, {
            ui.label({
                text = timeMain,
                fontSize = 11,
                fontWeight = "bold",
                color = "primary",
            }),

            ui.label({
                text = timeSub,
                fontSize = 9,
                color = "on_surface_variant",
            }),
        }),

        ui.column({
            flexGrow = 1,
            gap = 2,
            align = "start",
        }, {
            ui.label({
                text = tostring(event.name or ""),
                fontSize = 11,
                fontWeight = "medium",
                color = "on_surface",
                maxLines = 2,
            }),

            metaRow(event),
        }),
    })
end

-- =========================================================
-- RENDER
-- =========================================================

function render()
    local now = os.date("*t")
    local todayKey = dayKey(now.year, now.month, now.day)

    local firstDay = os.date("*t", os.time({
        year = viewYear,
        month = viewMonth,
        day = 1,
        hour = 12,
        min = 0,
        sec = 0,
    }))

    local offset = currentMonthOffset(firstDay)
    local gridStart = os.time({
        year = viewYear,
        month = viewMonth,
        day = 1 - offset,
        hour = 12,
        min = 0,
        sec = 0,
    })

    local weekdays = START_MONDAY and WEEKDAYS_MONDAY or WEEKDAYS_SUNDAY
    local weekdayHeader = {}

    for index = 1, 7 do
        weekdayHeader[index] = ui.column({
            width = 34,
            height = 14,
            align = "center",
            justify = "center",
        }, {
            ui.label({
                text = weekdays[index],
                fontSize = 9,
                fontWeight = "bold",
                color = "on_surface_variant",
                textAlign = "center",
            }),
        })
    end

    local gridRows = {}

    for week = 0, 5 do
        local cells = {}

        for weekday = 0, 6 do
            local cellTime = gridStart + (week * 7 + weekday) * 86400
            local t = os.date("*t", cellTime)
            local key = dayKey(t.year, t.month, t.day)

            cells[weekday + 1] = dayCell(
                t.year,
                t.month,
                t.day,
                t.year == viewYear and t.month == viewMonth,
                key == todayKey
            )
        end

        gridRows[week + 1] = ui.row({
            gap = 2,
            align = "center",
            justify = "center",
        }, cells)
    end

    local monthContent = {
        ui.row({
            height = 26,
            align = "center",
            justify = "space_between",
            gap = 4,
        }, {
            ui.button({
                glyph = "chevron-left",
                glyphSize = 16,
                variant = "ghost",
                controlSize = "sm",
                width = 26,
                height = 26,
                onClick = function()
                    shiftMonth(-1)
                end,
            }),

            ui.label({
                text = MONTH_NOMINATIVE[viewMonth] .. " " .. tostring(viewYear),
                fontSize = 14,
                fontWeight = "bold",
                color = "on_surface",
                textAlign = "center",
                flexGrow = 1,
            }),

            ui.row({
                gap = 2,
                align = "center",
            }, {
                ui.button({
                    glyph = "chevron-right",
                    glyphSize = 16,
                    variant = "ghost",
                    controlSize = "sm",
                    width = 26,
                    height = 26,
                    onClick = function()
                        shiftMonth(1)
                    end,
                }),

                ui.button({
                    text = "сегодня",
                    fontSize = 9,
                    variant = "ghost",
                    controlSize = "sm",
                    onClick = goToday,
                }),
            }),
        }),

        ui.row({
            gap = 2,
            align = "center",
            justify = "center",
        }, weekdayHeader),
    }

    for _, row in ipairs(gridRows) do
        table.insert(monthContent, row)
    end

    local monthCard = ui.column({
        width = 278,
        height = 312,
        padding = 12,
        gap = 6,
        fill = "surface/0.55",
        radius = 14,
        border = "primary/0.22",
        borderWidth = 1,
    }, monthContent)

    -- The events window only joins the layout while a day is expanded, exactly
    -- like the detail rows in the system-dashboard plugin.
    local function eventsPanel()
        local key = selectedKey

        if key == nil then
            return nil
        end

        local children = {}

        local selectedYear = tonumber(key:sub(1, 4))
        local selectedMonth = tonumber(key:sub(6, 7))
        local selectedDay = tonumber(key:sub(9, 10))

        local dayStartSec = os.time({
            year = selectedYear,
            month = selectedMonth,
            day = selectedDay,
            hour = 0,
            min = 0,
            sec = 0,
        })
        local dayEndSec = nextMidnight(dayStartSec)

        local dayEvents = eventsForDay(selectedYear, selectedMonth, selectedDay)

        local listRows = {}

        if #dayEvents == 0 then
            local emptyText = loading and "Читаю кэш Thunderbird…" or "Нет событий"

            listRows[1] = ui.column({
                flexGrow = 1,
                align = "center",
                justify = "center",
                gap = 8,
            }, {
                ui.glyph({
                    name = "calendar-off",
                    size = 30,
                    color = "on_surface_variant/0.5",
                }),

                ui.label({
                    text = emptyText,
                    fontSize = 11,
                    color = "on_surface_variant",
                }),
            })
        else
            for _, event in ipairs(dayEvents) do
                table.insert(
                    listRows,
                    eventRow(event, dayStartSec * 1000, dayEndSec * 1000)
                )
            end
        end

        local selectedWeekday = os.date("*t", dayStartSec).wday

        local headerRight = {
            ui.label({
                text = tostring(#dayEvents),
                fontSize = 12,
                fontWeight = "bold",
                color = "primary",
            }),
        }

        table.insert(children, ui.row({
            height = 36,
            align = "center",
            justify = "space_between",
            gap = 8,
        }, {
            ui.column({
                align = "start",
                gap = 0,
                flexGrow = 1,
            }, {
                ui.label({
                    text = WEEKDAY_FULL[selectedWeekday],
                    fontSize = 15,
                    fontWeight = "bold",
                    color = "on_surface",
                }),

                ui.label({
                    text = tostring(selectedDay)
                        .. " "
                        .. MONTH_GENITIVE[selectedMonth]
                        .. " "
                        .. tostring(selectedYear),
                    fontSize = 10,
                    color = "on_surface_variant",
                }),
            }),

            ui.column({
                align = "end",
                gap = 0,
            }, headerRight),
        }))

        table.insert(children, ui.separator({
            orientation = "horizontal",
            thickness = 1,
            color = "primary/0.2",
        }))

        table.insert(children, ui.scroll({
            flexGrow = 1,
            gap = 6,
        }, listRows))

        if lastError ~= nil then
            table.insert(children, ui.label({
                text = lastError,
                fontSize = 9,
                color = "error",
                maxLines = 1,
            }))
        end

        return ui.column({
            width = 306,
            height = 312,
            padding = 12,
            gap = 8,
            fill = "surface/0.55",
            radius = 14,
            border = "primary/0.22",
            borderWidth = 1,
        }, children)
    end

    local cards = { monthCard }
    local sidePanel = eventsPanel()

    if sidePanel ~= nil then
        table.insert(cards, sidePanel)
    end

    desktopWidget.render(ui.row({
        width = WIDGET_WIDTH,
        gap = 12,
        padding = 10,
        align = "start",
    }, cards))
end

-- =========================================================
-- LIFECYCLE
-- =========================================================

function update()
    noctalia.setUpdateInterval(REFRESH_SECONDS * 1000)

    local now = os.time()

    if not loading and now - lastRefreshAttempt >= REFRESH_SECONDS then
        refresh()
    else
        render()
    end
end

rebuildIndex()
