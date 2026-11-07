-- System Dashboard
-- Compact interactive Noctalia desktop widget
-- No external dependencies.

local DISK_PATH = "/"

-- Interaction state
local hoveredMetric = nil
local pinnedMetric = nil

local renderWidget

-- =========================================================
-- FORMATTING
-- =========================================================

local function clampPercent(value)
    local n = tonumber(value)

    if n == nil then
        return 0
    end

    return math.max(0, math.min(100, n))
end

local function percentText(value)
    if value == nil then
        return "--"
    end

    return string.format("%.0f%%", clampPercent(value))
end

local function formatGiB(mb)
    if mb == nil then
        return "--"
    end

    return string.format("%.1f GiB", mb / 1024)
end

local function formatBytes(bytes)
    local n = tonumber(bytes)

    if n == nil then
        return "--"
    end

    if n >= 1024 ^ 4 then
        return string.format("%.1f TiB", n / 1024 ^ 4)
    elseif n >= 1024 ^ 3 then
        return string.format("%.1f GiB", n / 1024 ^ 3)
    elseif n >= 1024 ^ 2 then
        return string.format("%.1f MiB", n / 1024 ^ 2)
    elseif n >= 1024 then
        return string.format("%.1f KiB", n / 1024)
    end

    return string.format("%.0f B", n)
end

local function formatSpeed(bytes)
    local n = tonumber(bytes)

    if n == nil then
        return "--"
    end

    if n >= 1024 ^ 2 then
        return string.format("%.1f MiB/s", n / 1024 ^ 2)
    elseif n >= 1024 then
        return string.format("%.1f KiB/s", n / 1024)
    end

    return string.format("%.0f B/s", n)
end

local function formatTemperature(value)
    if value == nil then
        return "Not available"
    end

    return string.format("%.0f°C", value)
end

local function formatFrequency(value)
    if value == nil then
        return "Not available"
    end

    return string.format("%.2f GHz", value / 1000)
end

local function isExpanded(id)
    return hoveredMetric == id or pinnedMetric == id
end

local function isPinned(id)
    return pinnedMetric == id
end

-- =========================================================
-- INTERACTION
-- =========================================================

local function handleHover(id, state)
    if state == "true" then
        hoveredMetric = id
    elseif hoveredMetric == id then
        hoveredMetric = nil
    end

    renderWidget()
end

local function togglePin(id)
    if pinnedMetric == id then
        pinnedMetric = nil
    else
        pinnedMetric = id
    end

    renderWidget()
end

-- =========================================================
-- UI HELPERS
-- =========================================================

local function separator()
    return ui.separator({
        orientation = "horizontal",
        thickness = 1,
        color = "primary/0.2",
    })
end

local function detailLine(label, value)
    return ui.row({
        align = "center",
        justify = "space_between",
        gap = 8,
    }, {
        ui.label({
            text = label,
            fontSize = 10,
            color = "on_surface_variant",
        }),

        ui.label({
            text = value,
            fontSize = 10,
            fontWeight = "medium",
            color = "on_surface",
        }),
    })
end

-- =========================================================
-- PERCENTAGE METRIC CARD
-- =========================================================

local function percentCard(id, label, glyph, value, details)
    local expanded = isExpanded(id)
    local pinned = isPinned(id)

    local children = {
        ui.row({
            align = "center",
            justify = "center",
            gap = 4,
        }, {
            ui.glyph({
                name = glyph,
                size = 15,
                color = "primary",
            }),

            ui.label({
                text = label,
                fontSize = 10,
                fontWeight = "bold",
                color = "on_surface_variant",
            }),
        }),

        ui.label({
            text = percentText(value),
            fontSize = 19,
            fontWeight = "bold",
            color = "on_surface",
        }),

        ui.progress({
            progress = clampPercent(value) / 100,
            width = 64,
            height = 4,
            radius = 4,
            fill = "primary",
            track = "surface/0.8",
        }),
    }

    if expanded then
        table.insert(children, separator())

        for _, detail in ipairs(details) do
            table.insert(children, detail)
        end

        if pinned then
            table.insert(children, ui.label({
                text = "PINNED",
                fontSize = 8,
                fontWeight = "bold",
                color = "primary",
            }))
        end
    end

    return ui.column({
        width = 88,
        padding = 7,
        gap = 6,
        align = "center",
        justify = "center",

        fill = expanded
            and "primary/0.12"
            or "surface/0.55",

        radius = 11,

        border = expanded
            and "primary/0.8"
            or "primary/0.2",

        borderWidth = 1,

        onHover = function(state)
            handleHover(id, state)
        end,

        onClick = function()
            togglePin(id)
        end,
    }, children)
end

-- =========================================================
-- CPU / RAM / SWAP
-- =========================================================

local function buildResourceCards(stats)
    local cards = {}

    local cpu = stats and stats.cpu or {}
    local ram = stats and stats.ram or {}
    local swap = stats and stats.swap or {}

    -- CPU
    table.insert(cards, percentCard(
        "cpu",
        "CPU",
        "cpu",
        cpu.usagePercent,
        {
            detailLine(
                "Temperature",
                formatTemperature(cpu.tempC)
            ),

            detailLine(
                "Frequency",
                formatFrequency(cpu.freqMhz)
            ),
        }
    ))

    -- RAM
    local ramUsed = tonumber(ram.usedMb)
    local ramTotal = tonumber(ram.totalMb)

    local ramFree = nil

    if ramUsed and ramTotal then
        ramFree = math.max(0, ramTotal - ramUsed)
    end

    table.insert(cards, percentCard(
        "ram",
        "RAM",
        "memory-stick",
        ram.usagePercent,
        {
            detailLine("Used", formatGiB(ramUsed)),
            detailLine("Free", formatGiB(ramFree)),
            detailLine("Total", formatGiB(ramTotal)),
        }
    ))

    -- SWAP: completely hidden when unavailable.
    local swapUsed = tonumber(swap.usedMb)
    local swapTotal = tonumber(swap.totalMb)

    if swapTotal and swapTotal > 0 then
        local swapFree = math.max(
            0,
            swapTotal - (swapUsed or 0)
        )

        local swapPercent =
            (swapUsed or 0) / swapTotal * 100

        table.insert(cards, percentCard(
            "swap",
            "SWAP",
            "repeat",
            swapPercent,
            {
                detailLine("Used", formatGiB(swapUsed)),
                detailLine("Free", formatGiB(swapFree)),
                detailLine("Total", formatGiB(swapTotal)),
            }
        ))
    end

    return ui.row({
        gap = 6,
        align = "start",
        justify = "center",
    }, cards)
end

-- =========================================================
-- NETWORK
-- =========================================================

local function buildNetwork(stats)
    local net = stats and stats.net or {}

    local rx = net.rxBytesPerSec
    local tx = net.txBytesPerSec

    local expanded = isExpanded("network")
    local pinned = isPinned("network")

    local children = {
        ui.row({
            align = "center",
            justify = "space_between",
            gap = 8,
        }, {
            ui.row({
                align = "center",
                gap = 5,
            }, {
                ui.glyph({
                    name = "activity",
                    size = 16,
                    color = "primary",
                }),

                ui.label({
                    text = "NET",
                    fontSize = 10,
                    fontWeight = "bold",
                    color = "on_surface_variant",
                }),
            }),

            ui.row({
                align = "center",
                gap = 12,
            }, {
                ui.row({
                    gap = 3,
                    align = "center",
                }, {
                    ui.glyph({
                        name = "arrow-down",
                        size = 13,
                        color = "primary",
                    }),

                    ui.label({
                        text = formatSpeed(rx),
                        fontSize = 11,
                        fontWeight = "bold",
                        color = "on_surface",
                    }),
                }),

                ui.row({
                    gap = 3,
                    align = "center",
                }, {
                    ui.glyph({
                        name = "arrow-up",
                        size = 13,
                        color = "primary",
                    }),

                    ui.label({
                        text = formatSpeed(tx),
                        fontSize = 11,
                        fontWeight = "bold",
                        color = "on_surface",
                    }),
                }),
            }),
        }),
    }

    if expanded then
        table.insert(children, separator())

        table.insert(children, detailLine(
            "Download",
            formatSpeed(rx)
        ))

        table.insert(children, detailLine(
            "Upload",
            formatSpeed(tx)
        ))

        table.insert(children, ui.label({
            text = "All non-loopback interfaces",
            fontSize = 9,
            color = "on_surface_variant",
        }))

        if pinned then
            table.insert(children, ui.label({
                text = "PINNED",
                fontSize = 8,
                fontWeight = "bold",
                color = "primary",
            }))
        end
    end

    return ui.column({
        padding = 9,
        gap = 7,

        fill = expanded
            and "primary/0.12"
            or "surface/0.55",

        radius = 11,

        border = expanded
            and "primary/0.8"
            or "primary/0.2",

        borderWidth = 1,

        onHover = function(state)
            handleHover("network", state)
        end,

        onClick = function()
            togglePin("network")
        end,
    }, children)
end

-- =========================================================
-- DISK
-- =========================================================

local function buildDisk(disk)
    local expanded = isExpanded("disk")
    local pinned = isPinned("disk")

    local usage = disk and tonumber(disk.usagePercent)
    local total = disk and tonumber(disk.totalBytes)
    local free = disk and tonumber(disk.freeBytes)
    local available = disk and tonumber(disk.availableBytes)

    local used = nil

    if total and free then
        used = math.max(0, total - free)
    end

    local children = {
        ui.row({
            align = "center",
            justify = "space_between",
        }, {
            ui.row({
                gap = 5,
                align = "center",
            }, {
                ui.glyph({
                    name = "hard-drive",
                    size = 16,
                    color = "primary",
                }),

                ui.label({
                    text = "DISK /",
                    fontSize = 10,
                    fontWeight = "bold",
                    color = "on_surface_variant",
                }),
            }),

            ui.label({
                text = percentText(usage),
                fontSize = 12,
                fontWeight = "bold",
                color = "on_surface",
            }),
        }),

        ui.progress({
            progress = clampPercent(usage) / 100,
            width = 245,
            height = 5,
            radius = 5,
            fill = "primary",
            track = "surface/0.8",
        }),
    }

    if expanded then
        table.insert(children, separator())

        table.insert(children, detailLine(
            "Used",
            formatBytes(used)
        ))

        table.insert(children, detailLine(
            "Free",
            formatBytes(free)
        ))

        table.insert(children, detailLine(
            "Available to user",
            formatBytes(available)
        ))

        table.insert(children, detailLine(
            "Total",
            formatBytes(total)
        ))

        if pinned then
            table.insert(children, ui.label({
                text = "PINNED",
                fontSize = 8,
                fontWeight = "bold",
                color = "primary",
            }))
        end
    end

    return ui.column({
        padding = 9,
        gap = 7,

        fill = expanded
            and "primary/0.12"
            or "surface/0.55",

        radius = 11,

        border = expanded
            and "primary/0.8"
            or "primary/0.2",

        borderWidth = 1,

        onHover = function(state)
            handleHover("disk", state)
        end,

        onClick = function()
            togglePin("disk")
        end,
    }, children)
end

-- =========================================================
-- MAIN RENDER
-- =========================================================

renderWidget = function()
    local stats = noctalia.systemStats()
    local disk = noctalia.diskStats(DISK_PATH)

    desktopWidget.render(ui.column({
        width = 300,
        padding = 10,
        gap = 8,

        fill = "surface/0.90",
        radius = 16,

        border = "primary/0.3",
        borderWidth = 1,
    }, {
        -- HEADER
        ui.row({
            align = "center",
            justify = "space_between",
        }, {
            ui.row({
                gap = 5,
                align = "center",
            }, {
                ui.glyph({
                    name = "activity",
                    size = 15,
                    color = "primary",
                }),

                ui.label({
                    text = "SYSTEM",
                    fontSize = 10,
                    fontWeight = "bold",
                    color = "primary",
                }),
            }),

            ui.label({
                text = pinnedMetric ~= nil
                    and "DETAILS PINNED"
                    or "LIVE",
                fontSize = 8,
                color = "on_surface_variant",
            }),
        }),

        -- CPU / RAM / SWAP
        buildResourceCards(stats),

        -- NETWORK
        buildNetwork(stats),

        -- DISK
        buildDisk(disk),
    }))
end

-- =========================================================
-- UPDATE
-- =========================================================

function update()
    noctalia.setUpdateInterval(1000)
    renderWidget()
end
