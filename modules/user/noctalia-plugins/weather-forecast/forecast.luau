-- Weather Forecast
-- Noctalia desktop widget: compact seven-day forecast and temperature curve.
-- The layout follows the existing local widgets: active Noctalia palette roles,
-- surface background, subtle primary border, and restrained rounded corners.
-- Weather provider: MET Norway Locationforecast (open, no API key required).

-- =========================================================
-- LOCATION AND REFRESH
-- =========================================================

-- Keep this aligned with [location] in user/kirill/modules/noctalia.nix.
local CITY = "НИЖНИЙ НОВГОРОД"
local LATITUDE = 56.3269
local LONGITUDE = 44.0059
-- Нижний Новгород: UTC+3.
local TARGET_UTC_OFFSET_HOURS = 3

-- MET Norway allows infrequent polling for non-Nordic locations; refresh every 3h.
local REFRESH_SECONDS = 3 * 60 * 60
local RETRY_SECONDS = 5 * 60
local UPDATE_INTERVAL_MS = 60 * 1000

-- MET Norway requires an identifying User-Agent.
local USER_AGENT = "Noctalia-Weather-Forecast/1.1 (https://srcoder.moe/)"

-- =========================================================
-- LAYOUT
-- =========================================================

local WIDGET_WIDTH = 420
local WIDGET_HEIGHT = 220

-- Seven equally-sized columns. The graph is inset by half a column on both
-- sides so its first and last samples sit under the centres of the outer days.
local DAY_CELL_WIDTH = 52
local DAY_COUNT = 7
local DAY_GRID_WIDTH = DAY_CELL_WIDTH * DAY_COUNT
local GRAPH_SIDE_INSET = DAY_CELL_WIDTH / 2
local GRAPH_WIDTH = DAY_GRID_WIDTH - DAY_CELL_WIDTH

-- =========================================================
-- STATE
-- =========================================================

local forecast = nil
local loading = false
local errorMessage = nil
local nextRequestAt = 0

local chartPath = nil
local chartColor = nil
local chartRendering = false
local chartSerial = 0
local renderChart

local WEEKDAYS = { "ВС", "ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ" }

-- =========================================================
-- FORMATTING AND WEATHER SYMBOLS
-- =========================================================

local function numberOrNil(value)
    local number = tonumber(value)
    return number
end

local function formatTemperature(value, explicitPlus)
    local number = numberOrNil(value)

    if number == nil then
        return "—"
    end

    if explicitPlus then
        return string.format("%+.0f°", number)
    end

    return string.format("%.0f°", number)
end

-- MET Norway symbol codes: clearsky_day, partlycloudy_night, lightrain, etc.
local function weatherInfo(symbol, isDay)
    local s = string.lower(tostring(symbol or ""))
    local day = s:find("_night", 1, true) == nil

    if isDay ~= nil then
        day = tonumber(isDay) ~= 0 or isDay == true
    end

    s = s:gsub("_day$", "")
    s = s:gsub("_night$", "")
    s = s:gsub("_polartwilight$", "")

    if s == "clearsky" then
        return "ЯСНО", day and "sun" or "moon"
    elseif s == "fair" then
        return "МАЛО ОБЛАКОВ", day and "cloud-sun" or "cloud-moon"
    elseif s == "partlycloudy" then
        return "ПЕРЕМЕННАЯ ОБЛАЧНОСТЬ", day and "cloud-sun" or "cloud-moon"
    elseif s == "cloudy" then
        return "ОБЛАЧНО", "cloud"
    elseif s:find("fog", 1, true) then
        return "ТУМАН", "cloud-fog"
    elseif s:find("thunder", 1, true) then
        return "ГРОЗА", "cloud-lightning"
    elseif s:find("sleet", 1, true) then
        return "МОКРЫЙ СНЕГ", "cloud-snow"
    elseif s:find("snow", 1, true) then
        return "СНЕГ", "cloud-snow"
    elseif s:find("drizzle", 1, true) then
        return "МОРОСЬ", "cloud-drizzle"
    elseif s:find("rain", 1, true)
        or s:find("showers", 1, true) then
        return "ДОЖДЬ", "cloud-rain"
    end

    return "НЕТ ДАННЫХ", "cloud-question"
end

local function dayLabel(index, weekday)
    if index == 1 then
        return "СЕГ"
    end

    return WEEKDAYS[weekday] or "—"
end

-- Converts a UTC timestamp from MET Norway into the target city's local date.
local function targetLocalDate(iso)
    local y, m, d, h, minute, second = string.match(
        iso or "",
        "^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)"
    )

    if not y then
        return nil
    end

    local pseudoLocal = os.time({
        year = tonumber(y),
        month = tonumber(m),
        day = tonumber(d),
        hour = tonumber(h),
        min = tonumber(minute),
        sec = tonumber(second),
    })

    local date = os.date(
        "*t",
        pseudoLocal + TARGET_UTC_OFFSET_HOURS * 3600
    )

    return {
        year = date.year,
        month = date.month,
        day = date.day,
        hour = date.hour,
        weekday = date.wday,
        key = string.format(
            "%04d-%02d-%02d",
            date.year,
            date.month,
            date.day
        ),
    }
end

-- Select the most useful weather symbol from a timeseries entry.
local function getSymbol(data)
    if type(data) ~= "table" then
        return nil
    end

    local periods = {
        data.next_1_hours,
        data.next_6_hours,
        data.next_12_hours,
    }

    for _, period in ipairs(periods) do
        if period
            and period.summary
            and period.summary.symbol_code then
            return period.summary.symbol_code
        end
    end

    return nil
end

-- =========================================================
-- FORECAST PARSING
-- =========================================================

local function buildForecast(data)
    if type(data) ~= "table"
        or type(data.properties) ~= "table"
        or type(data.properties.timeseries) ~= "table" then
        return nil
    end

    local timeseries = data.properties.timeseries

    if #timeseries == 0 then
        return nil
    end

    local days = {}
    local daysByKey = {}

    local first = timeseries[1]
    local firstData = first.data or {}
    local firstDetails = firstData.instant
        and firstData.instant.details
        or {}

    local currentTemperature = numberOrNil(firstDetails.air_temperature)
    local currentSymbol = getSymbol(firstData)

    -- Aggregate all available samples by local date.
    for _, entry in ipairs(timeseries) do
        local date = targetLocalDate(entry.time)

        if date then
            local key = date.key

            if not daysByKey[key] then
                local day = {
                    key = key,
                    weekday = date.weekday,
                    high = nil,
                    symbol = nil,
                    symbolDistance = math.huge,
                }

                daysByKey[key] = day
                table.insert(days, day)
            end

            local day = daysByKey[key]
            local entryData = entry.data or {}

            local details = entryData.instant
                and entryData.instant.details
                or {}

            local sixHours = entryData.next_6_hours
                and entryData.next_6_hours.details
                or {}

            local instantTemp = numberOrNil(details.air_temperature)
            local periodMax = numberOrNil(sixHours.air_temperature_max)

            if instantTemp ~= nil then
                day.high = day.high == nil
                    and instantTemp
                    or math.max(day.high, instantTemp)
            end

            if periodMax ~= nil then
                day.high = day.high == nil
                    and periodMax
                    or math.max(day.high, periodMax)
            end

            -- Prefer a weather symbol near local noon.
            local symbol = getSymbol(entryData)
            local distance = math.abs(date.hour - 12)

            if symbol and distance < day.symbolDistance then
                day.symbol = symbol
                day.symbolDistance = distance
            end
        end
    end

    local resultDays = {}

    for index = 1, math.min(DAY_COUNT, #days) do
        local day = days[index]

        if day.high ~= nil then
            local condition, glyph = weatherInfo(day.symbol or currentSymbol, true)

            table.insert(resultDays, {
                label = dayLabel(index, day.weekday),
                high = day.high,
                symbol = day.symbol or currentSymbol,
                condition = condition,
                glyph = glyph,
            })
        end
    end

    if currentTemperature == nil or #resultDays == 0 then
        return nil
    end

    local condition, currentGlyph = weatherInfo(currentSymbol, nil)

    return {
        current = {
            temperature = currentTemperature,
            condition = condition,
            glyph = currentGlyph,
        },
        days = resultDays,
    }
end

-- =========================================================
-- WEATHER REQUEST
-- =========================================================

local function requestForecast()
    if loading or os.time() < nextRequestAt then
        return
    end

    loading = true
    errorMessage = nil
    renderWidget()

    local url = string.format(
        "https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=%.4f&lon=%.4f",
        LATITUDE,
        LONGITUDE
    )

    local accepted = noctalia.http({
        url = url,
        method = "GET",
        headers = {
            "User-Agent: " .. USER_AGENT,
            "Accept: application/json",
        },
    }, function(response)
        loading = false

        if response == nil then
            errorMessage = "Нет ответа от MET Norway"
            nextRequestAt = os.time() + RETRY_SECONDS
            noctalia.log("[Weather Forecast] Empty response from MET Norway")
            renderWidget()
            return
        end

        if response.ok ~= true or tonumber(response.status) ~= 200 then
            errorMessage = "MET Norway HTTP " .. tostring(response.status)
            nextRequestAt = os.time() + RETRY_SECONDS
            noctalia.log("[Weather Forecast] HTTP error: " .. tostring(response.status))
            renderWidget()
            return
        end

        local data, decodeError = noctalia.json.decode(response.body or "")

        if type(data) ~= "table" then
            errorMessage = "Не удалось разобрать прогноз"
            nextRequestAt = os.time() + RETRY_SECONDS
            noctalia.log(
                "[Weather Forecast] JSON error: " .. tostring(decodeError)
            )
            renderWidget()
            return
        end

        local result = buildForecast(data)

        if result == nil then
            errorMessage = "Неполные данные прогноза"
            nextRequestAt = os.time() + RETRY_SECONDS
            noctalia.log("[Weather Forecast] Invalid forecast data")
            renderWidget()
            return
        end

        forecast = result
        errorMessage = nil
        nextRequestAt = os.time() + REFRESH_SECONDS
        chartPath = nil
        chartColor = nil

        noctalia.log(
            "[Weather Forecast] Loaded " .. tostring(#result.days) .. " daily points (MET Norway)"
        )

        renderWidget()
        if renderChart ~= nil then
            renderChart()
        end
    end)

    if accepted ~= true then
        loading = false
        errorMessage = "Не удалось запустить запрос погоды"
        nextRequestAt = os.time() + RETRY_SECONDS
        noctalia.log("[Weather Forecast] HTTP request was rejected")
        renderWidget()
    end
end

-- =========================================================
-- GRAPH
-- =========================================================

local function graphValues(days)
    if #days == 0 then
        return { 0.5, 0.5 }
    end

    if #days == 1 then
        return { 0.5, 0.5 }
    end

    local minimum = math.huge
    local maximum = -math.huge

    for _, day in ipairs(days) do
        minimum = math.min(minimum, day.high)
        maximum = math.max(maximum, day.high)
    end

    local anchors = {}
    local difference = maximum - minimum

    for _, day in ipairs(days) do
        if difference < 0.01 then
            table.insert(anchors, 0.5)
        else
            local normalized = (day.high - minimum) / difference
            table.insert(anchors, 0.16 + normalized * 0.68)
        end
    end

    local values = {}
    local stepsPerSegment = 10

    for index = 1, #anchors - 1 do
        local first = anchors[index]
        local second = anchors[index + 1]

        for step = 0, stepsPerSegment - 1 do
            local progress = step / stepsPerSegment
            local eased = (1 - math.cos(math.pi * progress)) / 2
            table.insert(values, first + (second - first) * eased)
        end
    end

    table.insert(values, anchors[#anchors])
    return values
end

local function placeholderDays()
    local days = {}

    for index = 1, DAY_COUNT do
        table.insert(days, {
            label = index == 1 and "СЕГ" or "—",
            high = nil,
            glyph = "cloud-question",
        })
    end

    return days
end

local function dayColumns(days, contentBuilder)
    local columns = {}

    for index = 1, DAY_COUNT do
        local day = days[index] or {
            label = "—",
            high = nil,
            glyph = "cloud-question",
        }

        table.insert(columns, ui.column({
            width = DAY_CELL_WIDTH,
            align = "center",
            justify = "center",
            gap = 1,
        }, contentBuilder(day, index)))
    end

    return ui.row({
        width = DAY_GRID_WIDTH,
        align = "center",
        justify = "start",
        gap = 0,
    }, columns)
end

-- =========================================================
-- WIDGET RENDER
-- =========================================================

function renderWidget()
    local days = forecast and forecast.days or placeholderDays()
    local values = forecast and graphValues(days) or { 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5 }

    local current = forecast and forecast.current or nil

    local headline = current
        and (current.condition .. " " .. formatTemperature(current.temperature, true))
        or (loading and "ЗАГРУЗКА ПОГОДЫ…" or "ПОГОДА НЕДОСТУПНА")

    local header = ui.row({
        width = WIDGET_WIDTH - 28,
        align = "center",
        justify = "space_between",
        gap = 8,
    }, {
        ui.label({
            text = headline,
            fontSize = 13,
            fontWeight = "bold",
            color = "primary",
            maxWidth = 230,
        }),

        ui.label({
            text = CITY,
            fontSize = 10,
            fontWeight = "medium",
            color = "on_surface_variant",
            textAlign = "right",
        }),
    })

    local temperatures = dayColumns(days, function(day)
        return {
            ui.label({
                text = day.high ~= nil and formatTemperature(day.high, false) or "—",
                fontSize = 11,
                fontWeight = "bold",
                color = "on_surface",
                textAlign = "center",
            }),
        }
    end)

    local graphContent

    if chartPath ~= nil then
        graphContent = ui.image({
            path = chartPath,
            width = GRAPH_WIDTH,
            height = 56,
            fit = "contain",
        })
    else
        graphContent = ui.graph({
            values = values,
            width = GRAPH_WIDTH,
            height = 56,
            color = "primary",
            lineWidth = 2.5,
            fillOpacity = 0.03,
        })
    end

    local graph = ui.row({
        width = DAY_GRID_WIDTH,
        align = "center",
        justify = "start",
        gap = 0,
    }, {
        ui.box({
            width = GRAPH_SIDE_INSET,
            height = 1,
            fill = "#00000000",
        }),

        graphContent,

        ui.box({
            width = GRAPH_SIDE_INSET,
            height = 1,
            fill = "#00000000",
        }),
    })

    local icons = dayColumns(days, function(day)
        return {
            ui.glyph({
                name = day.glyph or "cloud-question",
                size = 22,
                color = "primary",
            }),
        }
    end)

    local weekdayLabels = dayColumns(days, function(day)
        return {
            ui.label({
                text = day.label or "—",
                fontSize = 9,
                fontWeight = "medium",
                color = "on_surface_variant",
                textAlign = "center",
            }),
        }
    end)

    local children = {
        header,
        temperatures,
        graph,
        ui.spacer({ flexGrow = 1 }),
        icons,
        weekdayLabels,
    }

    if errorMessage ~= nil then
        table.insert(children, ui.label({
            text = errorMessage,
            fontSize = 8,
            color = "error",
            maxLines = 1,
        }))
    end

    desktopWidget.render(ui.column({
        width = WIDGET_WIDTH,
        height = WIDGET_HEIGHT,
        padding = 14,
        gap = 6,
        fill = "surface/0.90",
        radius = 16,
        border = "primary/0.3",
        borderWidth = 1,
    }, children))
end

-- =========================================================
-- DAILY GRAPH MARKERS
-- =========================================================

renderChart = function()
    if forecast == nil or chartRendering then
        return
    end

    local accent = noctalia.getColor("primary")
    if type(accent) ~= "string" or accent == "" then
        accent = "#57FF57"
    end

    if chartPath ~= nil and chartColor == accent then
        return
    end

    local pluginDir = noctalia.pluginDir()
    if pluginDir == nil then
        noctalia.log("[Weather Forecast] Plugin directory is unavailable")
        return
    end

    chartRendering = true
    chartSerial = chartSerial + 1

    local outputPath = "/tmp/noctalia-weather-forecast-"
        .. tostring(os.time())
        .. "-"
        .. tostring(chartSerial)
        .. ".png"

    local args = {
        "python3",
        pluginDir .. "/render_chart.py",
        outputPath,
        accent,
        tostring(#forecast.days),
    }

    for _, day in ipairs(forecast.days) do
        table.insert(args, string.format("%.2f", day.high))
    end

    local accepted = noctalia.runAsync(args, function(result)
        chartRendering = false

        if result == nil or tonumber(result.exitCode) ~= 0 then
            noctalia.log(
                "[Weather Forecast] Chart renderer failed: "
                    .. tostring(result and result.stderr or "no process result")
            )
        else
            chartPath = outputPath
            chartColor = accent
        end

        renderWidget()
    end)

    if accepted ~= true then
        chartRendering = false
        noctalia.log("[Weather Forecast] Could not start chart renderer")
    end
end

-- =========================================================
-- UPDATE LOOP
-- =========================================================

function update()
    noctalia.setUpdateInterval(UPDATE_INTERVAL_MS)
    requestForecast()
    renderChart()
    renderWidget()
end
