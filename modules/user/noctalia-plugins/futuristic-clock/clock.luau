
-- Futuristic Clock
-- Noctalia Desktop Widget
-- Weather provider: MET Norway Locationforecast API

-- =========================================================
-- CONFIGURATION
-- =========================================================

local CITY = "Нижний Новгород"

local LATITUDE = 56.3269
local LONGITUDE = 44.0059

-- Нижний Новгород: UTC+3.
-- Изменяй это значение, если выберешь другой город.
local TARGET_UTC_OFFSET_HOURS = 3

-- MET Norway: do not request the same location
-- more frequently than once every 3 hours outside Nordic areas.
local REFRESH_SECONDS = 3 * 60 * 60

-- MET Norway requires an identifying User-Agent.
local USER_AGENT = "FuturisticClock/1.0 (https://git.srcoder.moe/)"

-- =========================================================
-- STATE
-- =========================================================

local forecast = nil
local loading = false
local errorMessage = nil
local nextRequestAt = 0

local weekdays = {
    "ВС", "ПН", "ВТ", "СР", "ЧТ", "ПТ", "СБ"
}

local weekdayFull = {
    "ВОСКРЕСЕНЬЕ",
    "ПОНЕДЕЛЬНИК",
    "ВТОРНИК",
    "СРЕДА",
    "ЧЕТВЕРГ",
    "ПЯТНИЦА",
    "СУББОТА"
}

-- =========================================================
-- HELPERS
-- =========================================================

local function temp(value)
    local n = tonumber(value)

    if n == nil then
        return "—"
    end

    return string.format("%+.0f°", n)
end

-- MET Norway uses strings such as:
-- clearsky_day, partlycloudy_night, lightsnow, heavyrain.
local function weatherInfo(symbol)
    local s = string.lower(tostring(symbol or ""))

    s = s:gsub("_day$", "")
    s = s:gsub("_night$", "")
    s = s:gsub("_polartwilight$", "")

    if s == "clearsky" then
        return "ЯСНО", "sun"
    end

    if s == "fair" then
        return "МАЛО ОБЛАКОВ", "cloud-sun"
    end

    if s:find("thunder", 1, true) then
        return "ГРОЗА", "cloud-lightning"
    end

    if s:find("snow", 1, true)
        or s:find("sleet", 1, true) then
        return "СНЕГ", "cloud-snow"
    end

    if s:find("rain", 1, true) then
        return "ДОЖДЬ", "cloud-rain"
    end

    if s:find("fog", 1, true) then
        return "ТУМАН", "cloud-fog"
    end

    if s == "partlycloudy" then
        return "ПЕРЕМЕННАЯ ОБЛАЧНОСТЬ", "cloud-sun"
    end

    if s == "cloudy" then
        return "ОБЛАЧНО", "cloud"
    end

    return "НЕТ ДАННЫХ", "cloud-question"
end

-- Converts a UTC timestamp from MET Norway into the
-- target city's local calendar date.
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

local function formatForecastDate(day)
    return string.format(
        "%02d.%02d",
        day.day,
        day.month
    )
end

-- Select the most useful weather symbol from an entry.
local function getSymbol(data)
    if not data then
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
-- FORECAST PROCESSING
-- =========================================================

local function buildForecast(data)
    if not data
        or not data.properties
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
    local firstDetails =
        firstData.instant
        and firstData.instant.details
        or {}

    local current = {
        temperature = firstDetails.air_temperature,
        symbol = getSymbol(firstData),
    }

    -- Aggregate all available forecast samples by local date.
    for _, entry in ipairs(timeseries) do
        local date = targetLocalDate(entry.time)

        if date then
            local key = date.key

            if not daysByKey[key] then
                local day = {
                    key = key,
                    day = date.day,
                    month = date.month,
                    weekday = date.weekday,
                    max = nil,
                    min = nil,
                    symbol = nil,
                    symbolDistance = math.huge,
                }

                daysByKey[key] = day
                table.insert(days, day)
            end

            local day = daysByKey[key]
            local entryData = entry.data or {}

            local details =
                entryData.instant
                and entryData.instant.details
                or {}

            -- MET Norway supplies actual period min/max
            -- in next_6_hours when available.
            local sixHours =
                entryData.next_6_hours
                and entryData.next_6_hours.details
                or {}

            local instantTemp =
                tonumber(details.air_temperature)

            local periodMin =
                tonumber(sixHours.air_temperature_min)

            local periodMax =
                tonumber(sixHours.air_temperature_max)

            if instantTemp then
                day.min = day.min
                    and math.min(day.min, instantTemp)
                    or instantTemp

                day.max = day.max
                    and math.max(day.max, instantTemp)
                    or instantTemp
            end

            if periodMin then
                day.min = day.min
                    and math.min(day.min, periodMin)
                    or periodMin
            end

            if periodMax then
                day.max = day.max
                    and math.max(day.max, periodMax)
                    or periodMax
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

    for i = 1, math.min(7, #days) do
        local day = days[i]

        if day.max ~= nil and day.min ~= nil then
            table.insert(resultDays, day)
        end
    end

    if #resultDays == 0 then
        return nil
    end

    return {
        current = current,
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

    local url = string.format(
        "https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=%.4f&lon=%.4f",
        LATITUDE,
        LONGITUDE
    )

    noctalia.log("[Futuristic Clock] Requesting MET Norway")

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
            nextRequestAt = os.time() + 300

            noctalia.log("[Futuristic Clock] Empty response")
            return
        end

        noctalia.log(
            "[Futuristic Clock] HTTP status: "
            .. tostring(response.status)
        )

        if response.ok ~= true or tonumber(response.status) ~= 200 then
            errorMessage = "MET Norway HTTP "
                .. tostring(response.status)

            noctalia.log(
                "[Futuristic Clock] HTTP error: "
                .. string.sub(response.body or "", 1, 400)
            )

            nextRequestAt = os.time() + 300
            return
        end

        local data, decodeError =
            noctalia.json.decode(response.body or "")

        if type(data) ~= "table" then
            errorMessage = "Ошибка разбора JSON"

            noctalia.log(
                "[Futuristic Clock] JSON error: "
                .. tostring(decodeError)
            )

            nextRequestAt = os.time() + 300
            return
        end

        local result = buildForecast(data)

        if result == nil then
            errorMessage = "Некорректные данные прогноза"

            noctalia.log("[Futuristic Clock] Forecast parsing failed")
            nextRequestAt = os.time() + 300
            return
        end

        forecast = result
        errorMessage = nil
        nextRequestAt = os.time() + REFRESH_SECONDS

        noctalia.log(
            "[Futuristic Clock] Forecast loaded: "
            .. tostring(#result.days)
            .. " days"
        )
    end)

    if accepted ~= true then
        loading = false
        errorMessage = "Не удалось запустить запрос"

        noctalia.log("[Futuristic Clock] Request rejected")
        nextRequestAt = os.time() + 300
    end
end

-- =========================================================
-- FORECAST ROW
-- =========================================================

local function forecastRow(day)
    local _, glyph = weatherInfo(day.symbol)

    return ui.row({
        gap = 10,
        padding = 9,
        align = "center",
        justify = "space_between",
        fill = "surface/0.45",
        radius = 10,
        border = "primary/0.18",
        borderWidth = 1,
    }, {
        ui.column({
            gap = 2,
            align = "start",
            minWidth = 65,
        }, {
            ui.label({
                text = weekdays[day.weekday],
                fontSize = 12,
                fontWeight = "bold",
                color = "primary",
            }),

            ui.label({
                text = formatForecastDate(day),
                fontSize = 10,
                color = "on_surface_variant",
            }),
        }),

        ui.glyph({
            name = glyph,
            size = 22,
            color = "primary",
        }),

        ui.label({
            text = temp(day.max) .. " / " .. temp(day.min),
            fontSize = 12,
            fontWeight = "bold",
            color = "on_surface",
        }),
    })
end

-- =========================================================
-- WIDGET RENDER
-- =========================================================

local function renderWidget()
    local now = os.date("*t")

    local current = forecast and forecast.current or nil

    local condition, glyph =
        weatherInfo(current and current.symbol)

    local currentTemp =
        current and temp(current.temperature) or "—"

    local children = {
        -- WEEKDAY
        ui.label({
            text = weekdayFull[now.wday],
            fontSize = 14,
            fontWeight = "bold",
            color = "primary",
        }),

        -- DIGITAL CLOCK
        ui.label({
            text = os.date("%H:%M"),
            fontSize = 62,
            fontWeight = "bold",
            fontFamily = "monospace",
            color = "on_surface",
        }),

        -- DATE
        ui.label({
            text = os.date("%d.%m.%Y"),
            fontSize = 16,
            color = "on_surface_variant",
        }),

        ui.separator({
            orientation = "horizontal",
            thickness = 1,
            color = "primary/0.3",
        }),

        -- CURRENT WEATHER
        ui.row({
            gap = 14,
            align = "center",
        }, {
            ui.glyph({
                name = glyph,
                size = 40,
                color = "primary",
            }),

            ui.column({
                gap = 4,
                align = "start",
            }, {
                ui.label({
                    text = currentTemp .. "C",
                    fontSize = 30,
                    fontWeight = "bold",
                    color = "on_surface",
                }),

                ui.label({
                    text = condition,
                    fontSize = 11,
                    color = "on_surface_variant",
                }),

                ui.label({
                    text = CITY,
                    fontSize = 10,
                    color = "primary",
                }),
            }),
        }),

        ui.separator({
            orientation = "horizontal",
            thickness = 1,
            color = "primary/0.3",
        }),

        -- FORECAST TITLE
        ui.label({
            text = "7-DAY FORECAST",
            fontSize = 12,
            fontWeight = "bold",
            color = "primary",
        }),
    }

    -- SEVEN DAILY ROWS
    if forecast and forecast.days then
        for _, day in ipairs(forecast.days) do
            table.insert(children, forecastRow(day))
        end
    else
        table.insert(children, ui.label({
            text = errorMessage
                or (loading
                    and "Получение прогноза..."
                    or "Прогноз пока недоступен"),
            fontSize = 11,
            color = "on_surface_variant",
        }))
    end

    table.insert(children, ui.separator({
        orientation = "horizontal",
        thickness = 1,
        color = "primary/0.3",
    }))

    table.insert(children, ui.label({
        text = "WEATHER DATA / MET NORWAY",
        fontSize = 9,
        color = "on_surface_variant",
    }))

    -- VERTICAL PANEL
    desktopWidget.render(ui.column({
        gap = 12,
        padding = 16,
        width = 340,
        fill = "surface/0.90",
        radius = 20,
        border = "primary/0.35",
        borderWidth = 1,
    }, children))
end

-- =========================================================
-- UPDATE LOOP
-- =========================================================

function update()
    desktopWidget.setWantsSecondTicks(true)

    requestForecast()
    renderWidget()
end
