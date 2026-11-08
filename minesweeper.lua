local RunService = game:GetService("RunService")

--[[
    Blockerman Minesweeper | WindUI Solver UI
]]

local cloneref = (cloneref or clonereference or function(instance)
    return instance
end)

local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local HttpService = cloneref(game:GetService("HttpService"))
local Workspace = cloneref(workspace)

local WindUI
do
    local ok, result = pcall(function()
        return require("./src/Init")
    end)

    if ok then
        WindUI = result
    else
        if cloneref(game:GetService("RunService")):IsStudio() then
            WindUI = require(cloneref(ReplicatedStorage:WaitForChild("WindUI"):WaitForChild("Init")))
        else
            WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
        end
    end
end

-- */ Colors /* --
local Purple = Color3.fromHex("#7775F2")
local Yellow = Color3.fromHex("#ECA201")
local Green = Color3.fromHex("#10C550")
local Grey = Color3.fromHex("#83889E")
local Blue = Color3.fromHex("#257AF7")
local Red = Color3.fromHex("#EF4F1D")

-- ─────────────────────────────────────────────────────────
-- CONFIG
-- ─────────────────────────────────────────────────────────
local CFG = {
    -- Core solver
    Enabled = true,
    AutoSolve = true,
    AutoSetup = true,
    TrustFlags = true,
    MinesValueIsRemaining = false,

    -- Solver limits
    MaxBruteForce = 1000,
    MaxSolutions = 0, -- 0 = infinite
    MaxNodes = 500_000_000,
    MonteCarloSamples = 100_000,
    MaxSolveTime = 2.0,
    MaxDPOps = 10_000_000,
    MaxCascade = 12,
    Debounce = 0.02,

    -- Visualisation
    VisualsEnabled = true,
    ShowProbabilities = true,
    HighlightBest = true,
    ShowOverlayText = true,
    OverlayTransparency = 0.3,
    OverlayScale = 0.8,
    OverlayYOffset = 1.5,
    OverlayTextSize = 70,

    -- Misc
    Debug = false,
}

-- Forward functions so UI can exist before core initializes.
local Setup = function() end
local QueueSolve = function(_) end
local ClearAll = function() end
local Cleanup = function() end
local RefreshStatus = function() end
local ForceSolve = function() end
local GetBestTile = function() return nil end
local CoreError = nil
local CoreReady = false

local function RefreshVisualsNow()
    ClearAll()
    QueueSolve(true)
end

-- ─────────────────────────────────────────────────────────
-- WINDOW
-- ─────────────────────────────────────────────────────────
local Window = WindUI:CreateWindow({
    Title = "Blockerman Minesweeper | Solver",
    Folder = "BlockerMinesweeper",
    Icon = "solar:folder-2-bold-duotone",
    NewElements = true,
    HideSearchBar = false,
    OpenButton = {
        Title = "Open Minesweeper Solver",
        CornerRadius = UDim.new(1, 0),
        StrokeThickness = 3,
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
        Scale = 0.5,
        Color = ColorSequence.new(
            Color3.fromHex("#30FF6A"),
            Color3.fromHex("#e7ff2f")
        ),
    },
    Topbar = {
        Height = 44,
        ButtonsType = "Mac",
    },
})

Window:Tag({
    Title = "Minesweeper Solver",
    Icon = "github",
    Color = Color3.fromHex("#1c1c1c"),
    Border = true,
})

-- ─────────────────────────────────────────────────────────
-- TABS
-- ─────────────────────────────────────────────────────────
local SolverTab = Window:Tab({
    Title = "Solver",
    Icon = "solar:home-2-bold",
    IconColor = Grey,
    IconShape = "Square",
    Border = true,
})

local VisualsTab = Window:Tab({
    Title = "Visuals",
    Icon = "solar:check-square-bold",
    IconColor = Green,
    IconShape = "Square",
    Border = true,
})

local SettingsTab = Window:Tab({
    Title = "Settings",
    Icon = "solar:password-minimalistic-input-bold",
    IconColor = Purple,
    IconShape = "Square",
    Border = true,
})

local StatusTab = Window:Tab({
    Title = "Status",
    Icon = "solar:info-square-bold",
    IconColor = Blue,
    IconShape = "Square",
    Border = true,
})

-- ─────────────────────────────────────────────────────────
-- SOLVER TAB
-- ─────────────────────────────────────────────────────────
local CoreSection = SolverTab:Section({
    Title = "Core",
})

CoreSection:Toggle({
    Flag = "Enabled",
    Title = "Solver Enabled",
    Desc = "Master toggle for the solver",
    Value = CFG.Enabled,
    Callback = function(v)
        CFG.Enabled = v
        if not v then
            ClearAll()
        else
            QueueSolve(true)
        end
    end,
})

CoreSection:Space()

CoreSection:Toggle({
    Flag = "AutoSolve",
    Title = "Auto Solve",
    Desc = "Automatically recalculate when board changes",
    Value = CFG.AutoSolve,
    Callback = function(v)
        CFG.AutoSolve = v
        if v then
            QueueSolve(true)
        end
    end,
})

CoreSection:Space()

CoreSection:Toggle({
    Flag = "AutoSetup",
    Title = "Auto Setup",
    Desc = "Automatically rebuild grid when game starts",
    Value = CFG.AutoSetup,
    Callback = function(v)
        CFG.AutoSetup = v
    end,
})

CoreSection:Space()

CoreSection:Toggle({
    Flag = "TrustFlags",
    Title = "Trust Flags",
    Desc = "Treat existing flags as confirmed mines",
    Value = CFG.TrustFlags,
    Callback = function(v)
        CFG.TrustFlags = v
        QueueSolve(true)
    end,
})

CoreSection:Space()

CoreSection:Toggle({
    Flag = "MinesValueIsRemaining",
    Title = "Mines Value Is Remaining",
    Desc = "Use if the game's Mines value counts remaining mines",
    Value = CFG.MinesValueIsRemaining,
    Callback = function(v)
        CFG.MinesValueIsRemaining = v
        QueueSolve(true)
    end,
})

CoreSection:Space()

CoreSection:Button({
    Title = "Force Setup",
    Icon = "",
    Justify = "Center",
    Color = Blue,
    Callback = function()
        Setup()
        WindUI:Notify({
            Title = "Setup",
            Content = "Forced grid setup.",
            Icon = "refresh-cw",
            Duration = 3,
        })
    end,
})

CoreSection:Space()

CoreSection:Button({
    Title = "Force Solve",
    Icon = "",
    Justify = "Center",
    Color = Green,
    Callback = function()
        ForceSolve()
        WindUI:Notify({
            Title = "Solve",
            Content = "Forced solver pass.",
            Icon = "check",
            Duration = 3,
        })
    end,
})

CoreSection:Space()

CoreSection:Button({
    Title = "Clear Visuals",
    Icon = "",
    Justify = "Center",
    Color = Yellow,
    Callback = function()
        ClearAll()
        WindUI:Notify({
            Title = "Visuals",
            Content = "Cleared solver overlays.",
            Icon = "trash",
            Duration = 3,
        })
    end,
})

CoreSection:Space()

CoreSection:Button({
    Title = "Unload Solver",
    Icon = "shredder",
    Justify = "Center",
    Color = Red,
    Callback = function()
        Cleanup()
        WindUI:Notify({
            Title = "Cleanup",
            Content = "Solver connections cleaned up.",
            Icon = "trash",
            Duration = 3,
        })
    end,
})

local LimitsSection = SolverTab:Section({
    Title = "Solver Limits",
})

LimitsSection:Slider({
    Flag = "Debounce",
    Title = "Debounce",
    Desc = "Delay between automatic solves",
    IsTooltip = true,
    IsTextbox = false,
    Width = 260,
    Step = 0.01,
    Value = {
        Min = 0,
        Max = 0.5,
        Default = CFG.Debounce,
    },
    Callback = function(value)
        CFG.Debounce = value
    end,
})

LimitsSection:Space()

LimitsSection:Slider({
    Flag = "MaxSolveTime",
    Title = "Max Solve Time",
    Desc = "Time budget for each solve pass",
    IsTooltip = true,
    IsTextbox = false,
    Width = 260,
    Step = 0.1,
    Value = {
        Min = 0.1,
        Max = 10,
        Default = CFG.MaxSolveTime,
    },
    Callback = function(value)
        CFG.MaxSolveTime = value
    end,
})

LimitsSection:Space()

LimitsSection:Slider({
    Flag = "MaxBruteForce",
    Title = "Max Brute Force Tiles",
    Desc = "Maximum tiles for exact enumeration",
    IsTooltip = true,
    IsTextbox = false,
    Width = 260,
    Step = 10,
    Value = {
        Min = 10,
        Max = 5000,
        Default = CFG.MaxBruteForce,
    },
    Callback = function(value)
        CFG.MaxBruteForce = value
    end,
})

LimitsSection:Space()

LimitsSection:Slider({
    Flag = "MonteCarloSamples",
    Title = "Monte Carlo Samples",
    Desc = "Samples used for large partitions",
    IsTooltip = true,
    IsTextbox = false,
    Width = 260,
    Step = 1000,
    Value = {
        Min = 1000,
        Max = 500000,
        Default = CFG.MonteCarloSamples,
    },
    Callback = function(value)
        CFG.MonteCarloSamples = value
    end,
})

LimitsSection:Space()

LimitsSection:Slider({
    Flag = "MaxCascade",
    Title = "Max Cascade",
    Desc = "Probability cascade iterations",
    IsTooltip = true,
    IsTextbox = false,
    Width = 260,
    Step = 1,
    Value = {
        Min = 1,
        Max = 32,
        Default = CFG.MaxCascade,
    },
    Callback = function(value)
        CFG.MaxCascade = value
    end,
})

LimitsSection:Space()

LimitsSection:Slider({
    Flag = "MaxNodes",
    Title = "Max Nodes",
    Desc = "Backtracking node budget",
    IsTooltip = true,
    IsTextbox = false,
    Width = 260,
    Step = 1_000_000,
    Value = {
        Min = 1_000_000,
        Max = 1_000_000_000,
        Default = CFG.MaxNodes,
    },
    Callback = function(value)
        CFG.MaxNodes = value
    end,
})

LimitsSection:Space()

LimitsSection:Slider({
    Flag = "MaxDPOps",
    Title = "Max DP Ops",
    Desc = "Maximum global DP weighting operations",
    IsTooltip = true,
    IsTextbox = false,
    Width = 260,
    Step = 10_000,
    Value = {
        Min = 10_000,
        Max = 100_000_000,
        Default = CFG.MaxDPOps,
    },
    Callback = function(value)
        CFG.MaxDPOps = value
    end,
})

LimitsSection:Space()

LimitsSection:Slider({
    Flag = "MaxSolutions",
    Title = "Max Solutions",
    Desc = "0 = infinite",
    IsTooltip = true,
    IsTextbox = false,
    Width = 260,
    Step = 1000,
    Value = {
        Min = 0,
        Max = 1_000_000,
        Default = CFG.MaxSolutions,
    },
    Callback = function(value)
        CFG.MaxSolutions = value
    end,
})

-- ─────────────────────────────────────────────────────────
-- VISUALS TAB
-- ─────────────────────────────────────────────────────────
local VisualSection = VisualsTab:Section({
    Title = "Overlay Settings",
})

VisualSection:Toggle({
    Flag = "VisualsEnabled",
    Title = "Visuals Enabled",
    Desc = "Show solver overlays in workspace",
    Value = CFG.VisualsEnabled,
    Callback = function(v)
        CFG.VisualsEnabled = v
        RefreshVisualsNow()
    end,
})

VisualSection:Space()

VisualSection:Toggle({
    Flag = "ShowProbabilities",
    Title = "Show Probabilities",
    Desc = "Color unknown tiles by mine probability",
    Value = CFG.ShowProbabilities,
    Callback = function(v)
        CFG.ShowProbabilities = v
        RefreshVisualsNow()
    end,
})

VisualSection:Space()

VisualSection:Toggle({
    Flag = "HighlightBest",
    Title = "Highlight Best Tile",
    Desc = "Highlight the currently selected best tile",
    Value = CFG.HighlightBest,
    Callback = function(v)
        CFG.HighlightBest = v
        RefreshVisualsNow()
    end,
})

VisualSection:Space()

VisualSection:Toggle({
    Flag = "ShowOverlayText",
    Title = "Show Overlay Text",
    Desc = "Show X / ? markers on overlays",
    Value = CFG.ShowOverlayText,
    Callback = function(v)
        CFG.ShowOverlayText = v
        RefreshVisualsNow()
    end,
})

VisualSection:Space()

VisualSection:Slider({
    Flag = "OverlayTransparency",
    Title = "Overlay Transparency",
    IsTooltip = true,
    IsTextbox = false,
    Width = 260,
    Step = 0.05,
    Value = {
        Min = 0,
        Max = 1,
        Default = CFG.OverlayTransparency,
    },
    Callback = function(value)
        CFG.OverlayTransparency = value
        RefreshVisualsNow()
    end,
})

VisualSection:Space()

VisualSection:Slider({
    Flag = "OverlayScale",
    Title = "Overlay Scale",
    IsTooltip = true,
    IsTextbox = false,
    Width = 260,
    Step = 0.05,
    Value = {
        Min = 0.1,
        Max = 1,
        Default = CFG.OverlayScale,
    },
    Callback = function(value)
        CFG.OverlayScale = value
        RefreshVisualsNow()
    end,
})

VisualSection:Space()

VisualSection:Slider({
    Flag = "OverlayYOffset",
    Title = "Overlay Y Offset",
    IsTooltip = true,
    IsTextbox = false,
    Width = 260,
    Step = 0.1,
    Value = {
        Min = 0,
        Max = 5,
        Default = CFG.OverlayYOffset,
    },
    Callback = function(value)
        CFG.OverlayYOffset = value
        RefreshVisualsNow()
    end,
})

VisualSection:Space()

VisualSection:Slider({
    Flag = "OverlayTextSize",
    Title = "Overlay Text Size",
    IsTooltip = true,
    IsTextbox = false,
    Width = 260,
    Step = 5,
    Value = {
        Min = 10,
        Max = 150,
        Default = CFG.OverlayTextSize,
    },
    Callback = function(value)
        CFG.OverlayTextSize = value
        RefreshVisualsNow()
    end,
})

local VisualActionsSection = VisualsTab:Section({
    Title = "Visual Actions",
})

VisualActionsSection:Button({
    Title = "Focus Best Tile",
    Icon = "",
    Justify = "Center",
    Color = Purple,
    Callback = function()
        local best = GetBestTile()
        local cam = Workspace.CurrentCamera

        if best and best.Parent and cam then
            cam.CFrame = CFrame.new(cam.CFrame.Position, best.Position)
            WindUI:Notify({
                Title = "Camera",
                Content = "Focused best tile.",
                Icon = "check",
                Duration = 3,
            })
        else
            WindUI:Notify({
                Title = "Camera",
                Content = "No valid best tile found.",
                Icon = "alert-triangle",
                Duration = 3,
            })
        end
    end,
})

VisualActionsSection:Space()

VisualActionsSection:Button({
    Title = "Export Status JSON",
    Icon = "",
    Justify = "Center",
    Color = Green,
    Callback = function()
        local best = GetBestTile()

        local data = {
            GeneratedAt = os.date("%Y-%m-%d %H:%M:%S"),
            CoreReady = CoreReady,
            CoreError = CoreError,
            Config = CFG,
            Runtime = _G.UltraSolverInfo and _G.UltraSolverInfo() or nil,
            BestTile = best and {
                Name = best.Name,
                Position = {
                    X = best.Position.X,
                    Y = best.Position.Y,
                    Z = best.Position.Z,
                },
            } or nil,
        }

        local ok, json = pcall(function()
            return HttpService:JSONEncode(data)
        end)

        if ok and setclipboard then
            setclipboard(json)
            WindUI:Notify({
                Title = "Export",
                Content = "Status JSON copied to clipboard.",
                Icon = "copy",
                Duration = 3,
            })
        elseif ok then
            WindUI:Notify({
                Title = "Export",
                Content = "setclipboard is unavailable.",
                Icon = "alert-triangle",
                Duration = 3,
            })
        else
            WindUI:Notify({
                Title = "Export",
                Content = "Failed to encode JSON.",
                Icon = "alert-triangle",
                Duration = 3,
            })
        end
    end,
})

-- ─────────────────────────────────────────────────────────
-- SETTINGS TAB
-- ─────────────────────────────────────────────────────────
local InterfaceSection = SettingsTab:Section({
    Title = "Interface",
})

InterfaceSection:Keybind({
    Title = "UI Toggle Keybind",
    Desc = "Key used to open/close the window",
    Value = "RightShift",
    Callback = function(v)
        pcall(function()
            local kc = nil

            if typeof(v) == "EnumItem" and v.EnumType == Enum.KeyCode then
                kc = v
            elseif type(v) == "string" and Enum.KeyCode[v] ~= nil then
                kc = Enum.KeyCode[v]
            end

            if kc then
                Window:SetToggleKey(kc)
            end
        end)
    end,
})

InterfaceSection:Space()

InterfaceSection:Button({
    Title = "Destroy Window",
    Color = Red,
    Justify = "Center",
    Icon = "shredder",
    Callback = function()
        Cleanup()
        Window:Destroy()
    end,
})

local DebugSection = SettingsTab:Section({
    Title = "Debug",
})

DebugSection:Toggle({
    Flag = "DebugMode",
    Title = "Debug Mode",
    Desc = "Enables extra warn/print output where available",
    Value = CFG.Debug,
    Callback = function(v)
        CFG.Debug = v
    end,
})

-- ─────────────────────────────────────────────────────────
-- STATUS TAB
-- ─────────────────────────────────────────────────────────
local StatusSection = StatusTab:Section({
    Title = "Runtime Status",
})

local StatusOutput = StatusSection:Paragraph({
    Title = "Status",
    Desc = "Press Refresh Status to update this panel.",
})

StatusSection:Space()

StatusSection:Button({
    Title = "Refresh Status",
    Icon = "",
    Justify = "Center",
    Color = Blue,
    Callback = function()
        RefreshStatus()
    end,
})

-- ─────────────────────────────────────────────────────────
-- PROBLEMS TAB
-- ─────────────────────────────────────────────────────────
local ProblemsTab = Window:Tab({
    Title = "Problems",
    Icon = "solar:danger-triangle-bold",
    Border = true,
})

local InfoSection = ProblemsTab:Section({
    Title = "Executor Compatibility",
})

InfoSection:Paragraph({
    Title = "Why Features May Not Work",
    Desc = "This script requires specific executor functions to operate fully. If your executor does not support them, certain features will be disabled or non-functional:\n\n• writefile / readfile / isfile → Config saving/loading\n• printidentity() → WindUI ConfigManager initialization\n• setclipboard → Export/copy functions\n• cloneref → Safe service access (fallback exists)\n• game:HttpGet → Loading WindUI\n\nIf any of these are missing, the script will still load but with reduced functionality.",
    Color = Yellow,
})

InfoSection:Space()

InfoSection:Paragraph({
    Title = "Supported Executors",
    Desc = "Fully compatible: Synapse X, Fluxus, Wave, Codex, Delta\nPartially compatible: Solara, Swift (no config saving)\nIncompatible: Studio mode, executors without file access\n\nNote: Roblox updates can break hooks or instance layouts at any time.",
})

local TestSection = ProblemsTab:Section({
    Title = "Executor Diagnostic Test",
})

TestSection:Paragraph({
    Title = "How It Works",
    Desc = "Click 'Start Executor Test' below to check every function this script depends on. Results will appear below.",
})

TestSection:Space()

local TestOutput = TestSection:Paragraph({
    Title = "Test Results",
    Desc = "Press 'Start Executor Test' to begin diagnostics...",
})

TestSection:Space()

TestSection:Button({
    Title = "Start Executor Test",
    Icon = "",
    Justify = "Center",
    Color = Blue,
    Callback = function()
        pcall(function()
            TestOutput:SetDesc("Starting executor diagnostics...")
        end)

        task.wait(0.1)

        local results = {}
        local passCount = 0
        local failCount = 0

        local tests = {
            { Name = "writefile", Func = writefile, Purpose = "Config saving" },
            { Name = "readfile", Func = readfile, Purpose = "Config loading" },
            { Name = "isfile", Func = isfile, Purpose = "Config file checking" },
            { Name = "printidentity", Func = printidentity, Purpose = "WindUI ConfigManager init" },
            { Name = "setclipboard", Func = setclipboard, Purpose = "Export/copy to clipboard" },
            { Name = "cloneref", Func = cloneref or clonereference, Purpose = "Safe service referencing" },
            { Name = "game:HttpGet", Func = game and game.HttpGet, Purpose = "Loading WindUI library" },

            {
                Name = "HttpService:JSONEncode",
                Purpose = "Config/status serialization",
                IsCall = true,
                Func = function()
                    local ok = pcall(function()
                        return HttpService:JSONEncode({ test = true })
                    end)
                    return ok
                end,
            },

            {
                Name = "HttpService:JSONDecode",
                Purpose = "Config/status deserialization",
                IsCall = true,
                Func = function()
                    local ok = pcall(function()
                        return HttpService:JSONDecode('{"test":true}')
                    end)
                    return ok
                end,
            },

            {
                Name = "Workspace.Flag",
                Purpose = "Minesweeper board folder",
                IsCall = true,
                Func = function()
                    return Workspace:FindFirstChild("Flag") ~= nil
                end,
            },

            {
                Name = "ReplicatedStorage.Info",
                Purpose = "Game state container",
                IsCall = true,
                Func = function()
                    return ReplicatedStorage:FindFirstChild("Info") ~= nil
                end,
            },

            {
                Name = "ReplicatedStorage.Flags",
                Purpose = "Flag model container",
                IsCall = true,
                Func = function()
                    return ReplicatedStorage:FindFirstChild("Flags") ~= nil
                end,
            },
        }

        for _, test in ipairs(tests) do
            local passed = false

            if test.IsCall then
                local ok, res = pcall(test.Func)
                passed = ok and res == true
            else
                passed = type(test.Func) == "function"
            end

            local statusIcon = passed and "YES" or "NO"
            local line = string.format(
                "%s %s — %s (%s)",
                passed and "✅" or "❌",
                statusIcon,
                test.Name,
                test.Purpose
            )

            table.insert(results, line)

            if passed then
                passCount += 1
            else
                failCount += 1
            end

            pcall(function()
                TestOutput:SetDesc(table.concat(results, "\n"))
            end)

            task.wait(0.05)
        end

        task.wait(0.1)

        local summaryText = string.format(
            "\n━━━ SUMMARY ━━━\nPassed: %d | Failed: %d | Total: %d",
            passCount,
            failCount,
            #tests
        )

        if failCount == 0 then
            summaryText = summaryText .. "\n✅ Your executor is FULLY COMPATIBLE!"
        elseif failCount <= 3 then
            summaryText = summaryText .. "\n⚠️ PARTIALLY COMPATIBLE — Some features may not work."
        else
            summaryText = summaryText .. "\n❌ INCOMPATIBLE — Switch to a supported executor."
        end

        table.insert(results, summaryText)

        pcall(function()
            TestOutput:SetDesc(table.concat(results, "\n"))
        end)

        WindUI:Notify({
            Title = "Diagnostic Complete",
            Content = string.format("%d/%d checks passed. See Problems tab for details.", passCount, #tests),
            Icon = failCount == 0 and "check" or "alert-triangle",
            Duration = 4,
        })
    end,
})

local FixesSection = ProblemsTab:Section({
    Title = "Common Issues & Fixes",
})

FixesSection:Paragraph({
    Title = "Config Won't Save/Load",
    Desc = "Cause: Executor lacks writefile/readfile support.\nFix: Switch to Synapse X, Fluxus, Wave, Delta, or another executor with file APIs.",
})

FixesSection:Space()

FixesSection:Paragraph({
    Title = "Solver Does Nothing",
    Desc = "Cause: Game instances changed or the current board is not active.\nFix: Press Force Setup, ensure GameRunning is true, and verify the board parts exist.",
})

FixesSection:Space()

FixesSection:Paragraph({
    Title = "UI Doesn't Appear",
    Desc = "Cause: game:HttpGet blocked by executor or network.\nFix: Ensure your executor supports HttpGet and re-execute the script.",
})

FixesSection:Space()

FixesSection:Paragraph({
    Title = "Visuals Not Updating",
    Desc = "Cause: Visuals disabled, board unchanged, or debounce too high.\nFix: Enable Visuals, press Force Solve, and lower Debounce.",
})

-- ─────────────────────────────────────────────────────────
-- CONFIG TAB (optional, only if executor supports it)
-- ─────────────────────────────────────────────────────────
local canUseConfig = false
if not RunService:IsStudio()
    and type(writefile) == "function"
    and type(readfile) == "function"
    and type(isfile) == "function"
then
    local ok, res = pcall(function()
        return printidentity()
    end)
    canUseConfig = ok and res ~= false
end

if canUseConfig and Window.ConfigManager then
    local ConfigTab = Window:Tab({
        Title = "Config",
        Icon = "solar:folder-with-files-bold",
        IconColor = Purple,
        Border = true,
    })

    local ConfigManager = Window.ConfigManager
    local ConfigName = "default"

    local ConfigNameInput = ConfigTab:Input({
        Title = "Config Name",
        Icon = "file-cog",
        Callback = function(value)
            ConfigName = value
        end,
    })

    ConfigTab:Space()

    local AllConfigs = ConfigManager:AllConfigs()
    local DefaultValue = table.find(AllConfigs, ConfigName) and ConfigName or nil

    local AllConfigsDropdown = ConfigTab:Dropdown({
        Title = "All Configs",
        Desc = "Select existing configs",
        Values = AllConfigs,
        Value = DefaultValue,
        Callback = function(value)
            ConfigName = value
            pcall(function()
                ConfigNameInput:Set(value)
            end)
        end,
    })

    ConfigTab:Space()

    ConfigTab:Button({
        Title = "Save Config",
        Icon = "",
        Justify = "Center",
        Callback = function()
            Window.CurrentConfig = ConfigManager:Config(ConfigName)
            if Window.CurrentConfig:Save() then
                WindUI:Notify({
                    Title = "Config Saved",
                    Content = "Config '" .. ConfigName .. "' saved.",
                    Icon = "check",
                })
            end
            AllConfigsDropdown:Refresh(ConfigManager:AllConfigs())
        end,
    })

    ConfigTab:Space()

    ConfigTab:Button({
        Title = "Load Config",
        Icon = "",
        Justify = "Center",
        Callback = function()
            Window.CurrentConfig = ConfigManager:CreateConfig(ConfigName)
            if Window.CurrentConfig:Load() then
                WindUI:Notify({
                    Title = "Config Loaded",
                    Content = "Config '" .. ConfigName .. "' loaded.",
                    Icon = "refresh-cw",
                })
            end
        end,
    })

    ConfigTab:Space()

    ConfigTab:Button({
        Title = "Refresh Config List",
        Icon = "",
        Justify = "Center",
        Callback = function()
            AllConfigsDropdown:Refresh(ConfigManager:AllConfigs())
            WindUI:Notify({
                Title = "Config",
                Content = "Refreshed config list.",
                Icon = "refresh-cw",
            })
        end,
    })
end

-- Default status handler until core loads.
RefreshStatus = function()
    pcall(function()
        StatusOutput:SetDesc(
            "Core has not initialized yet."
            .. (CoreError and ("\nError: " .. tostring(CoreError)) or "")
        )
    end)
end

-- ─────────────────────────────────────────────────────────
-- CORE SOLVER INIT
-- ─────────────────────────────────────────────────────────
local ok, err = pcall(function()
    local FlagFolder = Workspace:WaitForChild("Flag", 10)
    local Parts = FlagFolder and FlagFolder:WaitForChild("Parts", 10)
    local Info = ReplicatedStorage:WaitForChild("Info", 10)
    local GameRunning = Info and Info:WaitForChild("GameRunning", 10)
    local MinesVal = Info and Info:FindFirstChild("Mines")
    local FlagsRoot = ReplicatedStorage:WaitForChild("Flags", 10)

    if not FlagFolder or not Parts or not Info or not GameRunning or not FlagsRoot then
        error("Required Blockerman Minesweeper instances were not found.")
    end

    -- ─── SETTINGS PARSE ─────────────────────────────────
    local function ReadSettings()
        local s = Info:FindFirstChild("Settings")
        local gx = s and (s:GetAttribute("GridSizeX") or s:GetAttribute("GridSize"))
        local gz = s and s:GetAttribute("GridSizeZ") or gx
        local ts = (s and s:GetAttribute("TileSize")) or 4

        if typeof(gx) == "Vector2" then
            gx, gz = gx.X, gx.Y
        elseif typeof(gx) == "Vector3" then
            gx, gz = gx.X, gx.Z
        end

        return gx, gz, ts, s
    end

    local GridW, GridH, TileStep, SettingsObj = ReadSettings()
    local TotalTiles = GridW and GridH and GridW * GridH or nil
    local TotalMines = MinesVal and MinesVal.Value or 0

    -- ─── VISUALISATION LAYER ────────────────────────────
    local VizFolder = nil

    local function EnsureVizFolder()
        if not VizFolder or not VizFolder.Parent then
            VizFolder = Instance.new("Folder")
            VizFolder.Name = "Solverstone"
            VizFolder.Parent = Workspace
        end
        return VizFolder
    end

    EnsureVizFolder()

    local COLOR = {
        Safe = Color3.fromRGB(0, 255, 0),
        Mine = Color3.fromRGB(255, 0, 0),
        Best = Color3.fromRGB(170, 0, 255),
        Unknown = Color3.fromRGB(255, 255, 0),
    }

    local function ProbColor(p)
        return p < 0.5
            and Color3.fromRGB(64, 224, 255):Lerp(Color3.fromRGB(255, 255, 0), p * 2)
            or Color3.fromRGB(255, 255, 0):Lerp(Color3.fromRGB(255, 110, 0), (p - 0.5) * 2)
    end

    local function RGBKey(c)
        return math.round(c.R * 255) * 65536
            + math.round(c.G * 255) * 256
            + math.round(c.B * 255)
    end

    local function MakeKey(r, g, b)
        return r * 65536 + g * 256 + b
    end

    local GREEN_KEYS = { [MakeKey(117, 205, 100)] = true, [MakeKey(103, 180, 88)] = true }
    local BEIGE_KEYS = { [MakeKey(255, 255, 125)] = true, [MakeKey(230, 230, 113)] = true }

    -- ─── PART POOL ──────────────────────────────────────
    local Pool = {}
    local Overlays = {}
    local DrawKey = {}

    local function PoolAcquire(tile)
        local vp = table.remove(Pool)

        if not vp then
            vp = Instance.new("Part")
            vp.Name = "SolverViz"
            vp.CastShadow = false
            vp.Material = Enum.Material.Neon
            vp.CanCollide = false
            vp.CanQuery = false
            vp.Anchored = true

            local sg = Instance.new("SurfaceGui")
            sg.Name = "SurfaceGui"
            sg.Face = Enum.NormalId.Top
            sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
            sg.PixelsPerStud = 25
            sg.Parent = vp

            local lb = Instance.new("TextLabel")
            lb.Name = "Label"
            lb.BackgroundTransparency = 1
            lb.BorderSizePixel = 0
            lb.Size = UDim2.new(1, 0, 1, 0)
            lb.AnchorPoint = Vector2.new(0.5, 0.5)
            lb.Position = UDim2.new(0.5, 0, 0.5, 0)
            lb.Font = Enum.Font.SourceSansBold
            lb.TextColor3 = Color3.new(0, 0, 0)
            lb.TextSize = 70
            lb.TextStrokeTransparency = 0.6
            lb.Parent = sg
        end

        vp.Size = tile.Size * math.clamp(CFG.OverlayScale, 0.05, 1)
        vp.Position = tile.Position + Vector3.new(0, CFG.OverlayYOffset, 0)
        vp.Parent = EnsureVizFolder()

        local sg = vp:FindFirstChildOfClass("SurfaceGui")
        local lb = sg and sg:FindFirstChildOfClass("TextLabel")
        if lb then
            lb.TextSize = CFG.OverlayTextSize
        end

        return vp
    end

    local function PoolRelease(vp)
        vp.Parent = nil
        table.insert(Pool, vp)
    end

    local function Draw(tile, col, text, hidden)
        if not CFG.VisualsEnabled then
            return
        end

        if not CFG.ShowOverlayText then
            text = ""
        end

        local key = RGBKey(col) * 4 + (hidden and 2 or 0) + (text ~= "" and 1 or 0)
        if DrawKey[tile] == key then
            return
        end

        DrawKey[tile] = key

        local vp = Overlays[tile] or PoolAcquire(tile)
        Overlays[tile] = vp
        vp.Color = col
        vp.Transparency = hidden and 1 or math.clamp(CFG.OverlayTransparency, 0, 1)

        local sg = vp:FindFirstChildOfClass("SurfaceGui")
        local lb = sg and sg:FindFirstChildOfClass("TextLabel")
        if lb then
            lb.Text = text
            lb.TextTransparency = hidden and 1 or 0
        end
    end

    local function Undraw(tile)
        local vp = Overlays[tile]
        if not vp then
            return
        end
        PoolRelease(vp)
        Overlays[tile] = nil
        DrawKey[tile] = nil
    end

    local function ClearAllCore()
        for tile in next, Overlays do
            Undraw(tile)
        end
    end

    -- ─── GRID INFRASTRUCTURE ────────────────────────────
    local function GridKey(gx, gz)
        return (gx + 4096) * 8192 + (gz + 4096)
    end

    local GridStep = nil
    local Grid = {}
    local Adjacency = {}
    local TileIndex = {}
    local TileCount = 0
    local BoundsDirty = true
    local BoardBounds = nil
    local LastSig = nil

    local OFFSETS = {
        { -1, -1 }, { 0, -1 }, { 1, -1 },
        { -1, 0 }, { 1, 0 },
        { -1, 1 }, { 0, 1 }, { 1, 1 },
    }

    local function TileGridPos(t)
        local stepX = TileStep or (GridStep and GridStep.X)
        local stepZ = TileStep or (GridStep and GridStep.Z)
        if not stepX or not stepZ then
            return nil, nil
        end
        return math.round(t.Position.X / stepX),
               math.round(t.Position.Z / stepZ)
    end

    local function IsEdge(gx, gz)
        return GridW and GridH
            and (gx <= 1 or gx >= GridW or gz <= 1 or gz >= GridH)
    end

    local function IsCorner(gx, gz)
        return GridW and GridH
            and (gx <= 1 or gx >= GridW) and (gz <= 1 or gz >= GridH)
    end

    local function RefreshBounds()
        BoundsDirty = false

        if GridW and GridH then
            BoardBounds = { MinX = 1, MinZ = 1, W = GridW, H = GridH }
            return
        end

        local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge

        for t in next, Adjacency do
            local gx, gz = TileGridPos(t)
            if gx then
                if gx < minX then minX = gx end
                if gx > maxX then maxX = gx end
                if gz < minZ then minZ = gz end
                if gz > maxZ then maxZ = gz end
            end
        end

        BoardBounds = (minX < math.huge)
            and { MinX = minX, MinZ = minZ, W = maxX - minX + 1, H = maxZ - minZ + 1 }
            or nil
    end

    -- ─── TILE METADATA ──────────────────────────────────
    local FlagModelNames = {}

    local function RebuildFlagNames()
        local t = {}
        for _, sub in ipairs(FlagsRoot:GetChildren()) do
            if sub:IsA("Folder") then
                for _, m in ipairs(sub:GetChildren()) do
                    t[m.Name] = true
                end
            end
        end
        FlagModelNames = t
    end

    RebuildFlagNames()

    local function HasFlag(tile)
        for _, c in ipairs(tile:GetChildren()) do
            if c:IsA("Model") and FlagModelNames[c.Name] then
                return true
            end
        end
        return false
    end

    local function GetNumber(tile)
        local g = tile:FindFirstChild("NumberGui")
        local l = g and g:FindFirstChild("TextLabel")
        return (l and tonumber(l.Text)) or 0
    end

    -- ─── CONNECTION BOOKKEEPING ─────────────────────────
    local ConnColor = {}
    local ConnDesc = {}
    local ConnText = {}
    local ConnFlag = {}
    local ConnTop = {}

    local LastBestTile = nil
    local LastSolveInfo = {}

    -- ─── SOLVE QUEUE ────────────────────────────────────
    local Solving = false
    local Pending = false
    local PendingForce = false

    local Solve

    local function QueueSolveCore(force)
        if not GameRunning.Value then
            LastSig = nil
            ClearAllCore()
            return
        end

        if not CFG.Enabled then
            LastSig = nil
            ClearAllCore()
            return
        end

        if not force and not CFG.AutoSolve then
            return
        end

        if Solving then
            Pending = true
            PendingForce = PendingForce or (force == true)
            return
        end

        Solving = true

        task.delay(CFG.Debounce, function()
            Solving = false

            local useForce = PendingForce
            PendingForce = false

            local solveOk, solveErr = pcall(Solve)
            if not solveOk then
                warn("[BlockermanSolver] " .. tostring(solveErr))
            end

            if Pending then
                Pending = false
                QueueSolveCore(useForce)
            end
        end)
    end

    -- ─── SOLVER ─────────────────────────────────────────
    Solve = function()
        if not CFG.Enabled or not GameRunning.Value then
            ClearAllCore()
            return
        end

        RebuildFlagNames()

        local hasMines = MinesVal ~= nil
        local mineTotal = hasMines and MinesVal.Value or 0
        TotalMines = mineTotal

        local MaxSolutions = (CFG.MaxSolutions <= 0) and math.huge or CFG.MaxSolutions

        local greenTiles = {}
        local beigeSet = {}
        local flagged = {}
        local NEG_INF = -math.huge
        local sig = (TileCount * 2246822519 + mineTotal * 3266489917) % 4294967291

        for t in next, Adjacency do
            local k = RGBKey(t.Color)

            if BEIGE_KEYS[k] then
                beigeSet[t] = true
                sig = (sig + (k + GetNumber(t) * 97 + 11) * 31 + 7) % 4294967291
            elseif GREEN_KEYS[k] then
                greenTiles[#greenTiles + 1] = t
                local fl = HasFlag(t)
                flagged[t] = fl
                sig = (sig + (k + (fl and 6151 or 0)) * 31 + 7) % 4294967291
            else
                sig = (sig + k * 31 + 7) % 4294967291
            end
        end

        if sig == LastSig then
            return
        end

        if BoundsDirty then
            RefreshBounds()
        end

        local state = {}
        for _, t in ipairs(greenTiles) do
            state[t] = 0
        end

        if CFG.TrustFlags then
            for _, t in ipairs(greenTiles) do
                if flagged[t] then
                    state[t] = 2
                end
            end
        end

        local cons = {}
        local consOf = {}
        local contra = false

        local function BuildConstraints()
            cons, consOf, contra = {}, {}, false

            for b in next, beigeSet do
                local n = GetNumber(b)

                if n > 0 then
                    local c = { Set = {}, List = {}, Rem = n }

                    for _, nb in ipairs(Adjacency[b]) do
                        local s = state[nb]

                        if s == 0 then
                            c.Set[nb] = true
                            c.List[#c.List + 1] = nb

                            local lst = consOf[nb]
                            if not lst then
                                lst = {}
                                consOf[nb] = lst
                            end
                            lst[#lst + 1] = c
                        elseif s == 2 then
                            c.Rem -= 1
                        end
                    end

                    if #c.List > 0 then
                        cons[#cons + 1] = c
                    elseif c.Rem ~= 0 then
                        contra = true
                    end
                end
            end
        end

        local function Propagate()
            local changed = false

            for _, c in ipairs(cons) do
                local target = (c.Rem == 0) and 1 or (c.Rem >= #c.List and 2 or 0)

                if target ~= 0 then
                    for _, t in ipairs(c.List) do
                        if state[t] == 0 then
                            state[t] = target
                            changed = true
                        end
                    end
                end
            end

            return changed
        end

        local function SubsetClosure()
            local resolved = false

            for _ = 1, 32 do
                local n, seen, newOnes, added = #cons, {}, {}, false

                for i = 1, n do
                    local ids = {}
                    for _, t in ipairs(cons[i].List) do
                        ids[#ids + 1] = TileIndex[t]
                    end
                    table.sort(ids)

                    local h = 0
                    for _, id in ipairs(ids) do
                        h = (h * 131 + id) % 4294967291
                    end
                    seen[h] = true
                end

                for i = 1, n do
                    local a = cons[i]
                    local cand = {}

                    for _, t in ipairs(a.List) do
                        for _, b in ipairs(consOf[t] or {}) do
                            if b ~= a and #b.List > #a.List then
                                cand[b] = true
                            end
                        end
                    end

                    for b in next, cand do
                        local sub = true

                        for _, t in ipairs(a.List) do
                            if not b.Set[t] then
                                sub = false
                                break
                            end
                        end

                        if sub then
                            local rem = b.Rem - a.Rem
                            local diff = {}

                            for _, t in ipairs(b.List) do
                                if not a.Set[t] then
                                    diff[#diff + 1] = t
                                end
                            end

                            if #diff > 0 then
                                if rem == 0 or rem == #diff then
                                    local s = (rem == 0) and 1 or 2

                                    for _, t in ipairs(diff) do
                                        if state[t] == 0 then
                                            state[t] = s
                                            resolved = true
                                        end
                                    end
                                else
                                    local ids = {}
                                    for _, t in ipairs(diff) do
                                        ids[#ids + 1] = TileIndex[t]
                                    end
                                    table.sort(ids)

                                    local h = 0
                                    for _, id in ipairs(ids) do
                                        h = (h * 131 + id) % 4294967291
                                    end

                                    if not seen[h] then
                                        seen[h] = true

                                        local nc = { Set = {}, List = diff, Rem = rem }

                                        for _, t in ipairs(diff) do
                                            nc.Set[t] = true
                                            local lst = consOf[t]
                                            if not lst then
                                                lst = {}
                                                consOf[t] = lst
                                            end
                                            lst[#lst + 1] = nc
                                        end

                                        newOnes[#newOnes + 1] = nc
                                        added = true
                                    end
                                end
                            end
                        end
                    end
                end

                for _, nc in ipairs(newOnes) do
                    cons[#cons + 1] = nc
                end

                if resolved or not added then
                    break
                end
            end

            return resolved
        end

        local function GaussianElim()
            if #cons == 0 then
                return false
            end

            local tileList, tilePos = {}, {}

            for _, c in ipairs(cons) do
                for _, t in ipairs(c.List) do
                    if not tilePos[t] then
                        tileList[#tileList + 1] = t
                        tilePos[t] = #tileList
                    end
                end
            end

            local nv = #tileList
            local nc = #cons

            if nv == 0 then
                return false
            end

            local mat = {}

            for ri, c in ipairs(cons) do
                local row = table.create(nv + 1, 0)

                for _, t in ipairs(c.List) do
                    row[tilePos[t]] = 1
                end

                row[nv + 1] = c.Rem
                mat[ri] = row
            end

            local pivot = {}
            local pr = 1

            for col = 1, nv do
                local found = nil

                for r = pr, nc do
                    if mat[r][col] == 1 then
                        found = r
                        break
                    end
                end

                if found then
                    mat[pr], mat[found] = mat[found], mat[pr]
                    pivot[col] = pr

                    for r = 1, nc do
                        if r ~= pr and mat[r][col] == 1 then
                            local rowR = mat[r]
                            local rowP = mat[pr]

                            for c2 = col, nv + 1 do
                                rowR[c2] = rowR[c2] - rowP[c2]
                                if rowR[c2] < 0 then
                                    rowR[c2] += 2
                                end
                            end
                        end
                    end

                    pr += 1
                end
            end

            local resolved = false

            for r = 1, nc do
                local row = mat[r]
                local rhs = row[nv + 1]

                local nonzero, lastCol = 0, 0

                for col = 1, nv do
                    if row[col] ~= 0 then
                        nonzero += 1
                        lastCol = col
                    end
                end

                if nonzero == 1 then
                    local t = tileList[lastCol]

                    if rhs == 0 and state[t] == 0 then
                        state[t] = 1
                        resolved = true
                    elseif rhs == 1 and state[t] == 0 then
                        state[t] = 2
                        resolved = true
                    end
                end
            end

            return resolved
        end

        local function Deduct()
            for _ = 1, 64 do
                BuildConstraints()

                if contra then
                    return false
                end

                for _, c in ipairs(cons) do
                    if c.Rem < 0 or c.Rem > #c.List then
                        return false
                    end
                end

                local ch = Propagate()

                if SubsetClosure() then
                    ch = true
                end

                if GaussianElim() then
                    ch = true
                end

                if not ch then
                    break
                end
            end

            return true
        end

        local function ComputeBudget()
            if not hasMines then
                return math.huge
            end

            local found = 0

            for _, t in ipairs(greenTiles) do
                if state[t] == 2 then
                    if not (CFG.MinesValueIsRemaining and CFG.TrustFlags and flagged[t]) then
                        found += 1
                    end
                end
            end

            return math.max(0, math.floor(
                CFG.MinesValueIsRemaining and mineTotal - found or mineTotal - found + 0.5
            ))
        end

        local function MakeSearch(tiles)
            local n = #tiles
            local tIdx = {}

            for i = 1, n do
                tIdx[tiles[i]] = i
            end

            local cSet, cList = {}, {}

            for i = 1, n do
                for _, c in ipairs(consOf[tiles[i]] or {}) do
                    if not cSet[c] then
                        cSet[c] = true
                        cList[#cList + 1] = c
                    end
                end
            end

            local nc = #cList
            local vCon = table.create(n)
            local cVar = table.create(nc)
            local cRem = table.create(nc)

            for i = 1, n do
                vCon[i] = {}
            end

            for ci = 1, nc do
                local c = cList[ci]
                cRem[ci] = c.Rem

                local vars = {}

                for _, t in ipairs(c.List) do
                    local vi = tIdx[t]
                    if vi then
                        vars[#vars + 1] = vi
                        local vc = vCon[vi]
                        vc[#vc + 1] = ci
                    end
                end

                cVar[ci] = vars
            end

            local placed = table.create(nc, 0)
            local left = table.create(nc, 0)

            for ci = 1, nc do
                left[ci] = #cVar[ci]
            end

            local asgn = table.create(n, -1)
            local trail = {}
            local mines = {}
            local count = 0
            local propQ = {}

            local function assign(v, val)
                asgn[v] = val
                trail[#trail + 1] = v
                count += 1

                if val == 1 then
                    mines[#mines + 1] = v
                end

                for _, ci in ipairs(vCon[v]) do
                    left[ci] -= 1
                    if val == 1 then
                        placed[ci] += 1
                    end
                    propQ[#propQ + 1] = ci
                end
            end

            local function prop()
                while #propQ > 0 do
                    local ci = propQ[#propQ]
                    propQ[#propQ] = nil

                    local need = cRem[ci] - placed[ci]
                    local lft = left[ci]

                    if need < 0 or need > lft then
                        for i = 1, #propQ do
                            propQ[i] = nil
                        end
                        return false
                    end

                    if lft > 0 then
                        local forced = (need == 0) and 0 or (need == lft and 1 or -1)

                        if forced >= 0 then
                            for _, vi in ipairs(cVar[ci]) do
                                if asgn[vi] == -1 then
                                    assign(vi, forced)
                                end
                            end
                        end
                    end
                end

                return true
            end

            local function undo(mark)
                while #trail > mark do
                    local v = trail[#trail]
                    trail[#trail] = nil

                    local val = asgn[v]
                    asgn[v] = -1
                    count -= 1

                    if val == 1 then
                        mines[#mines] = nil
                    end

                    for _, ci in ipairs(vCon[v]) do
                        left[ci] += 1
                        if val == 1 then
                            placed[ci] -= 1
                        end
                    end
                end
            end

            return {
                N = n,
                NC = nc,
                VCon = vCon,
                CVar = cVar,
                CRem = cRem,
                Placed = placed,
                Left = left,
                Asgn = asgn,
                Trail = trail,
                Mines = mines,
                Count = function()
                    return count
                end,
                Assign = assign,
                Prop = prop,
                Undo = undo,
            }
        end

        local nodesBudget = { n = 0 }
        local deadline = os.clock() + CFG.MaxSolveTime
        local maxBudget = math.huge

        local function Enumerate(tiles)
            local s = MakeSearch(tiles)

            local n, nc = s.N, s.NC
            local cVar = s.CVar
            local cRem = s.CRem
            local placed = s.Placed
            local left = s.Left
            local asgn = s.Asgn
            local trail = s.Trail
            local mines = s.Mines
            local assign = s.Assign
            local prop = s.Prop
            local undo = s.Undo
            local vCon = s.VCon

            local cbm = {}
            local freq = table.create(n)
            local total = 0
            local aborted = false
            local localN = 0

            local function pickVar()
                local bestV, bestSlack, bestDeg = -1, math.huge, -1

                for ci = 1, nc do
                    if left[ci] > 0 then
                        local slack = left[ci] - (cRem[ci] - placed[ci])

                        if slack < bestSlack then
                            bestSlack = slack
                            bestV = -1
                            bestDeg = -1

                            for _, v in ipairs(cVar[ci]) do
                                if asgn[v] == -1 then
                                    local d = #vCon[v]
                                    if d > bestDeg then
                                        bestDeg = d
                                        bestV = v
                                    end
                                end
                            end
                        end
                    end
                end

                return bestV
            end

            local function bt()
                if aborted then
                    return
                end

                localN += 1
                nodesBudget.n += 1

                if localN % 512 == 0 and (nodesBudget.n >= CFG.MaxNodes or os.clock() > deadline) then
                    aborted = true
                    return
                end

                if s.Count() == n then
                    total += 1

                    local m = #mines
                    cbm[m] = (cbm[m] or 0) + 1

                    for _, v in ipairs(mines) do
                        local f = freq[v]
                        if not f then
                            f = {}
                            freq[v] = f
                        end
                        f[m] = (f[m] or 0) + 1
                    end

                    if total >= MaxSolutions then
                        aborted = true
                    end

                    return
                end

                local v = pickVar()
                if v < 0 then
                    return
                end

                local mark = #trail

                assign(v, 0)
                if prop() then
                    bt()
                end
                undo(mark)

                if aborted then
                    return
                end

                if #mines + 1 <= maxBudget then
                    assign(v, 1)
                    if prop() then
                        bt()
                    end
                    undo(mark)
                end
            end

            bt()

            return cbm, freq, total, aborted
        end

        local function SamplePart(tiles)
            local s = MakeSearch(tiles)

            local n = s.N
            local vCon = s.VCon
            local cRem = s.CRem
            local placed = s.Placed
            local left = s.Left
            local asgn = s.Asgn
            local mines = s.Mines
            local assign = s.Assign
            local prop = s.Prop
            local undo = s.Undo

            local order = table.create(n)
            for i = 1, n do
                order[i] = i
            end

            local density

            if hasMines and TotalTiles then
                local unrevealed = math.max(1, TotalTiles - TileCount + #greenTiles)
                density = math.clamp(mineTotal / unrevealed, 0.02, 0.98)
            elseif hasMines then
                density = math.clamp(mineTotal / math.max(1, #greenTiles), 0.02, 0.98)
            else
                density = 0.21
            end

            local cbmS = {}
            local freqS = table.create(n)
            local valid = 0

            for sampleIndex = 1, CFG.MonteCarloSamples do
                if sampleIndex % 32 == 0 and os.clock() > deadline then
                    break
                end

                for i = n, 2, -1 do
                    local j = math.random(i)
                    order[i], order[j] = order[j], order[i]
                end

                local okSample = true

                for pos = 1, n do
                    local v = order[pos]

                    if asgn[v] == -1 then
                        local canMine, canSafe, pn, pd = true, true, 0, 0

                        for _, ci in ipairs(vCon[v]) do
                            local need = cRem[ci] - placed[ci]

                            if need <= 0 then
                                canMine = false
                            end

                            if need > left[ci] - 1 then
                                canSafe = false
                            end

                            pn += need
                            pd += left[ci]
                        end

                        if canMine and canSafe then
                            local val = (math.random() < (pd > 0 and pn / pd or density)) and 1 or 0
                            assign(v, val)

                            if not prop() then
                                okSample = false
                                break
                            end
                        elseif canMine then
                            assign(v, 1)

                            if not prop() then
                                okSample = false
                                break
                            end
                        elseif canSafe then
                            assign(v, 0)

                            if not prop() then
                                okSample = false
                                break
                            end
                        else
                            okSample = false
                            break
                        end
                    end
                end

                if okSample and s.Count() == n then
                    valid += 1

                    local m = #mines
                    cbmS[m] = (cbmS[m] or 0) + 1

                    for _, v in ipairs(mines) do
                        local f = freqS[v]
                        if not f then
                            f = {}
                            freqS[v] = f
                        end
                        f[m] = (f[m] or 0) + 1
                    end
                end

                undo(0)
            end

            return cbmS, freqS, valid
        end

        local okDeduct = Deduct()

        if not okDeduct and CFG.TrustFlags then
            for _, t in ipairs(greenTiles) do
                state[t] = 0
            end
            Deduct()
        end

        do
            local b = ComputeBudget()

            if b ~= math.huge then
                local unknowns = {}

                for _, t in ipairs(greenTiles) do
                    if state[t] == 0 then
                        unknowns[#unknowns + 1] = t
                    end
                end

                if #unknowns > 0 then
                    if b == 0 then
                        for _, t in ipairs(unknowns) do
                            state[t] = 1
                        end
                        Deduct()
                    elseif b == #unknowns then
                        for _, t in ipairs(unknowns) do
                            state[t] = 2
                        end
                        Deduct()
                    end
                end
            end
        end

        if not GameRunning.Value then
            ClearAllCore()
            return
        end

        local prob = {}
        local freeProb = 0.5
        local frontier = {}
        local freeTiles = {}
        local failedParts = {}

        local lastPartCount = 0
        local lastFailedCount = 0

        for cascade = 1, CFG.MaxCascade do
            if os.clock() > deadline then
                break
            end

            local budget = ComputeBudget()
            local nUnknown = 0

            for _, t in ipairs(greenTiles) do
                if state[t] == 0 then
                    nUnknown += 1
                end
            end

            if budget ~= math.huge then
                budget = math.min(budget, nUnknown)
                maxBudget = budget
            end

            prob, frontier, freeTiles = {}, {}, {}

            for _, t in ipairs(greenTiles) do
                if state[t] == 0 then
                    if consOf[t] then
                        frontier[#frontier + 1] = t
                    else
                        freeTiles[#freeTiles + 1] = t
                    end
                end
            end

            local parts, visited = {}, {}

            for _, seed in ipairs(frontier) do
                if not visited[seed] then
                    local component = {}
                    local q, qh = { seed }, 1
                    visited[seed] = true

                    while qh <= #q do
                        local cur = q[qh]
                        qh += 1

                        component[#component + 1] = cur

                        for _, c in ipairs(consOf[cur] or {}) do
                            for _, u in ipairs(c.List) do
                                if not visited[u] then
                                    visited[u] = true
                                    q[#q + 1] = u
                                end
                            end
                        end
                    end

                    table.sort(component, function(a, b)
                        local ax, az = TileGridPos(a)
                        local bx, bz = TileGridPos(b)

                        if ax and bx then
                            if ax ~= bx then
                                return ax < bx
                            end
                            if az ~= bz then
                                return az < bz
                            end
                        end

                        return (TileIndex[a] or 0) < (TileIndex[b] or 0)
                    end)

                    parts[#parts + 1] = component
                end
            end

            local partData = {}
            failedParts = {}

            for _, tiles in ipairs(parts) do
                local done = false

                if #tiles <= CFG.MaxBruteForce then
                    local cbm, freq, total, aborted = Enumerate(tiles)

                    if not aborted and total > 0 then
                        partData[#partData + 1] = { Tiles = tiles, Cbm = cbm, Freq = freq, Tot = total }
                        done = true
                    end
                end

                if not done then
                    local cbmS, freqS, valid = SamplePart(tiles)

                    if valid > 0 then
                        partData[#partData + 1] = { Tiles = tiles, Cbm = cbmS, Freq = freqS, Tot = valid }
                    else
                        failedParts[#failedParts + 1] = tiles
                    end
                end
            end

            lastPartCount = #partData
            lastFailedCount = #failedParts

            if not GameRunning.Value then
                ClearAllCore()
                return
            end

            if hasMines and budget ~= math.huge and #partData > 0 then
                local frontierMin, frontierMax = 0, 0

                for _, pdt in ipairs(partData) do
                    local lo, hi = math.huge, 0

                    for k in next, pdt.Cbm do
                        if k < lo then lo = k end
                        if k > hi then hi = k end
                    end

                    if lo < math.huge then
                        frontierMin += lo
                        frontierMax += hi
                    end
                end

                local freeMin = budget - frontierMax
                local freeMax = budget - frontierMin
                local nFree = #freeTiles

                if nFree > 0 then
                    if freeMax <= 0 then
                        for _, t in ipairs(freeTiles) do
                            if state[t] == 0 then
                                state[t] = 1
                            end
                        end
                        Deduct()
                    elseif freeMin >= nFree then
                        for _, t in ipairs(freeTiles) do
                            if state[t] == 0 then
                                state[t] = 2
                            end
                        end
                        Deduct()
                    end
                end

                for _, pdt in ipairs(partData) do
                    local lo, hi = math.huge, 0

                    for k in next, pdt.Cbm do
                        if k < lo then lo = k end
                        if k > hi then hi = k end
                    end

                    if lo == hi and lo < math.huge then
                        local tot = pdt.Tot

                        for v, fk in next, pdt.Freq do
                            local cnt = fk[lo] or 0
                            local t = pdt.Tiles[v]

                            if state[t] == 0 then
                                if cnt == tot then
                                    state[t] = 2
                                elseif cnt == 0 then
                                    state[t] = 1
                                end
                            end
                        end
                    end
                end
            end

            local allUnknown = {}

            for _, t in ipairs(greenTiles) do
                if state[t] == 0 then
                    allUnknown[#allUnknown + 1] = t
                end
            end

            local endgameThreshold = CFG.MaxBruteForce

            if #allUnknown > 0 and #allUnknown <= endgameThreshold and #allUnknown <= 60 then
                local cbmG, freqG, totalG, abortedG = Enumerate(allUnknown)

                if not abortedG and totalG > 0 then
                    partData = {{ Tiles = allUnknown, Cbm = cbmG, Freq = freqG, Tot = totalG }}
                    freeTiles = {}
                end
            end

            local NEG = -math.huge
            local p = #partData
            local weighted = false
            freeProb = 0.5

            local function LogAdd(a, b)
                if a == NEG then return b end
                if b == NEG then return a end

                if a < b then
                    a, b = b, a
                end

                return a + math.log(1 + math.exp(b - a))
            end

            local function LogComb(n, k)
                if k < 0 or k > n then
                    return NEG
                end

                k = math.min(k, n - k)

                local s = 0

                for i = 1, k do
                    s += math.log(n - k + i) - math.log(i)
                end

                return s
            end

            if hasMines and p > 0 then
                local pre = { [0] = { [0] = 0 } }

                for i = 1, p do
                    local row = {}

                    for m, w in next, pre[i - 1] do
                        for k, c in next, partData[i].Cbm do
                            local nm = m + k

                            if nm <= budget then
                                row[nm] = LogAdd(row[nm] or NEG, w + math.log(c))
                            end
                        end
                    end

                    local mx = NEG
                    for _, w in next, row do
                        if w > mx then
                            mx = w
                        end
                    end

                    if mx > NEG then
                        local cut = mx - 40
                        for m, w in next, row do
                            if w < cut then
                                row[m] = nil
                            end
                        end
                    end

                    pre[i] = row
                end

                local suf = { [p + 1] = { [0] = 0 } }

                for i = p, 1, -1 do
                    local row = {}

                    for m, w in next, suf[i + 1] do
                        for k, c in next, partData[i].Cbm do
                            local nm = m + k

                            if nm <= budget then
                                row[nm] = LogAdd(row[nm] or NEG, w + math.log(c))
                            end
                        end
                    end

                    local mx = NEG
                    for _, w in next, row do
                        if w > mx then
                            mx = w
                        end
                    end

                    if mx > NEG then
                        local cut = mx - 40
                        for m, w in next, row do
                            if w < cut then
                                row[m] = nil
                            end
                        end
                    end

                    suf[i] = row
                end

                local f = #freeTiles
                local lcCache = {}

                local function LC(k)
                    local v = lcCache[k]
                    if v == nil then
                        v = LogComb(f, k)
                        lcCache[k] = v
                    end
                    return v
                end

                local wTotal = NEG

                for m, wgt in next, pre[p] do
                    wTotal = LogAdd(wTotal, wgt + LC(budget - m))
                end

                if wTotal > NEG then
                    local ops = 0

                    for i = 1, p do
                        local a, b = 0, 0

                        for _ in next, pre[i - 1] do
                            a += 1
                        end

                        for _ in next, suf[i + 1] do
                            b += 1
                        end

                        ops += a * b
                    end

                    if ops <= CFG.MaxDPOps then
                        weighted = true

                        for i, pdt in ipairs(partData) do
                            local others = {}

                            for m1, w1 in next, pre[i - 1] do
                                for m2, w2 in next, suf[i + 1] do
                                    local x = m1 + m2
                                    others[x] = LogAdd(others[x] or NEG, w1 + w2)
                                end
                            end

                            local wo = {}

                            for k in next, pdt.Cbm do
                                local acc = NEG

                                for x, wgt in next, others do
                                    acc = LogAdd(acc, wgt + LC(budget - k - x))
                                end

                                wo[k] = acc
                            end

                            for v, fk in next, pdt.Freq do
                                local num = NEG

                                for k, c in next, fk do
                                    num = LogAdd(num, math.log(c) + (wo[k] or NEG))
                                end

                                prob[pdt.Tiles[v]] = math.clamp(math.exp(num - wTotal), 0, 1)
                            end

                            for _, t in ipairs(pdt.Tiles) do
                                if prob[t] == nil then
                                    prob[t] = 0
                                end
                            end
                        end

                        if f > 0 then
                            local num = NEG

                            for m, wgt in next, pre[p] do
                                local fm = budget - m

                                if fm > 0 then
                                    num = LogAdd(num, wgt + LC(fm) + math.log(fm))
                                end
                            end

                            freeProb = math.clamp(math.exp(num - wTotal) / f, 0, 1)
                        else
                            freeProb = 1
                        end
                    end
                end
            end

            if not weighted then
                for _, pdt in ipairs(partData) do
                    for v, fk in next, pdt.Freq do
                        local s = 0

                        for _, c in next, fk do
                            s += c
                        end

                        prob[pdt.Tiles[v]] = s / pdt.Tot
                    end

                    for _, t in ipairs(pdt.Tiles) do
                        if prob[t] == nil then
                            prob[t] = 0
                        end
                    end
                end

                if #freeTiles > 0 then
                    if hasMines then
                        if TotalTiles then
                            local unrevealed = TotalTiles - TileCount
                            local unknownMines = math.max(0, mineTotal - (#greenTiles - nUnknown))
                            freeProb = math.clamp(unknownMines / math.max(1, unrevealed), 0, 1)
                        else
                            freeProb = math.clamp(budget / math.max(1, nUnknown), 0, 1)
                        end
                    else
                        freeProb = 0.25
                    end
                end
            end

            local resolved = false

            for t, pv in next, prob do
                if pv <= 1e-7 then
                    state[t] = 1
                    resolved = true
                elseif pv >= 1 - 1e-7 then
                    state[t] = 2
                    resolved = true
                end
            end

            if not resolved or cascade == CFG.MaxCascade then
                break
            end

            Deduct()
        end

        BuildConstraints()

        frontier, freeTiles = {}, {}

        for _, t in ipairs(greenTiles) do
            if state[t] == 0 then
                if consOf[t] then
                    frontier[#frontier + 1] = t
                else
                    freeTiles[#freeTiles + 1] = t
                end
            end
        end

        local function InfoScore(t)
            local gx, gz = TileGridPos(t)
            local s = 0

            for _, nb in ipairs(Adjacency[t]) do
                if state[nb] == 0 then
                    s += 1
                    if consOf[nb] then
                        s += 2
                    end
                end
            end

            if gx and IsEdge(gx, gz) then
                s -= 1
                if IsCorner(gx, gz) then
                    s -= 1
                end
            end

            return s
        end

        local bestTile, bestProb, bestInfo = nil, math.huge, -1
        local TIE = 0.002

        local function Consider(t, pv)
            if not t then
                return
            end

            local inf = InfoScore(t)

            if pv < bestProb - TIE or (math.abs(pv - bestProb) <= TIE and inf > bestInfo) then
                bestProb = pv
                bestTile = t
                bestInfo = inf
            end
        end

        for t, pv in next, prob do
            if state[t] == 0 then
                Consider(t, pv)
            end
        end

        local function Centroid(tiles)
            local cx, cy, cz, n = 0, 0, 0, #tiles

            for _, t in ipairs(tiles) do
                local p = t.Position
                cx += p.X
                cy += p.Y
                cz += p.Z
            end

            return Vector3.new(cx / n, cy / n, cz / n)
        end

        local function Nearest(tiles, c)
            local best, bd = tiles[1], math.huge

            for _, t in ipairs(tiles) do
                local d = (t.Position - c).Magnitude
                if d < bd then
                    bd = d
                    best = t
                end
            end

            return best
        end

        for _, tiles in ipairs(failedParts) do
            local est = hasMines
                and math.clamp(mineTotal / math.max(1, #greenTiles), 0, 1)
                or 0.5

            Consider(Nearest(tiles, Centroid(tiles)), est)
        end

        if #freeTiles > 0 then
            local bf, bfp, bi = nil, math.huge, -1

            for _, t in ipairs(freeTiles) do
                local inf = InfoScore(t)

                if freeProb < bfp - 1e-9 or (math.abs(freeProb - bfp) <= 1e-9 and inf > bi) then
                    bfp = freeProb
                    bf = t
                    bi = inf
                end
            end

            if bf then
                Consider(bf, bfp)
            end
        end

        if not GameRunning.Value then
            ClearAllCore()
            return
        end

        local unknownCount = 0

        for _, t in ipairs(greenTiles) do
            if state[t] == 0 then
                unknownCount += 1
            end
        end

        LastBestTile = bestTile
        LastSolveInfo = {
            Time = os.clock(),
            GreenTiles = #greenTiles,
            Unknown = unknownCount,
            MineTotal = mineTotal,
            BestProbability = bestProb,
            Constraints = #cons,
            Partitions = lastPartCount,
            FailedPartitions = lastFailedCount,
        }

        if not CFG.VisualsEnabled then
            ClearAllCore()
            LastSig = sig
            return
        end

        local drawn = {}

        for _, t in ipairs(greenTiles) do
            local s = state[t]
            local onBoundary = false

            for _, nb in ipairs(Adjacency[t]) do
                if beigeSet[nb] then
                    onBoundary = true
                    break
                end
            end

            if s == 2 and onBoundary then
                Draw(t, COLOR.Mine, CFG.ShowOverlayText and "X" or "", HasFlag(t))
                drawn[t] = true
            elseif s == 1 and onBoundary then
                Draw(t, COLOR.Safe, "", false)
                drawn[t] = true
            elseif s == 0 and onBoundary then
                local pv = prob[t]
                local col

                if t == bestTile and CFG.HighlightBest then
                    col = COLOR.Best
                elseif pv and CFG.ShowProbabilities then
                    col = ProbColor(pv)
                else
                    col = COLOR.Unknown
                end

                Draw(t, col, CFG.ShowOverlayText and "?" or "", false)
                drawn[t] = true
            elseif s == 0 and t == bestTile and CFG.HighlightBest then
                Draw(t, COLOR.Best, CFG.ShowOverlayText and "?" or "", false)
                drawn[t] = true
            end
        end

        for t in next, Overlays do
            if not drawn[t] then
                Undraw(t)
            end
        end

        LastSig = sig
    end

    -- ─── TILE REGISTRATION ──────────────────────────────
    local function HookDescendant(d)
        if d:IsA("TextLabel") and not ConnText[d] then
            ConnText[d] = d:GetPropertyChangedSignal("Text"):Connect(function()
                QueueSolveCore(false)
            end)
        end
    end

    local function OnFlagEvent(child)
        if child:IsA("Model") then
            if not FlagModelNames[child.Name] then
                RebuildFlagNames()
            end

            if FlagModelNames[child.Name] then
                QueueSolveCore(false)
            end
        end
    end

    local function RegisterTile(tile, skipQueue)
        if not tile:IsA("BasePart") or Adjacency[tile] then
            return
        end

        Adjacency[tile] = {}
        TileCount += 1
        TileIndex[tile] = TileCount

        local gx, gz

        if TileStep then
            gx = math.round(tile.Position.X / TileStep)
            gz = math.round(tile.Position.Z / TileStep)
        else
            if not GridStep then
                GridStep = { X = tile.Size.X, Z = tile.Size.Z }
            end

            gx = math.round(tile.Position.X / GridStep.X)
            gz = math.round(tile.Position.Z / GridStep.Z)
        end

        for _, off in ipairs(OFFSETS) do
            local neighbor = Grid[GridKey(gx + off[1], gz + off[2])]

            if neighbor then
                local an = Adjacency[neighbor]
                Adjacency[tile][#Adjacency[tile] + 1] = neighbor
                an[#an + 1] = tile
            end
        end

        Grid[GridKey(gx, gz)] = tile
        BoundsDirty = true

        ConnColor[tile] = tile:GetPropertyChangedSignal("Color"):Connect(function()
            QueueSolveCore(false)
        end)

        for _, d in ipairs(tile:GetDescendants()) do
            HookDescendant(d)
        end

        ConnDesc[tile] = tile.DescendantAdded:Connect(HookDescendant)

        ConnFlag[tile] = {
            tile.ChildAdded:Connect(OnFlagEvent),
            tile.ChildRemoved:Connect(OnFlagEvent),
        }

        if not skipQueue then
            QueueSolveCore(false)
        end
    end

    local function SwapRemove(tbl, target)
        for i, v in ipairs(tbl) do
            if v == target then
                tbl[i] = tbl[#tbl]
                tbl[#tbl] = nil
                return
            end
        end
    end

    local function UnregisterTile(tile)
        Undraw(tile)

        if ConnColor[tile] then
            ConnColor[tile]:Disconnect()
            ConnColor[tile] = nil
        end

        if ConnDesc[tile] then
            ConnDesc[tile]:Disconnect()
            ConnDesc[tile] = nil
        end

        if ConnFlag[tile] then
            for _, c in ipairs(ConnFlag[tile]) do
                c:Disconnect()
            end
            ConnFlag[tile] = nil
        end

        for _, d in ipairs(tile:GetDescendants()) do
            if ConnText[d] then
                ConnText[d]:Disconnect()
                ConnText[d] = nil
            end
        end

        local step = TileStep or (GridStep and GridStep.X)

        if step then
            local gx = math.round(tile.Position.X / step)
            local gz = math.round(tile.Position.Z / (TileStep or GridStep.Z))
            local k = GridKey(gx, gz)

            if Grid[k] == tile then
                Grid[k] = nil
            end
        end

        if Adjacency[tile] then
            for _, nb in ipairs(Adjacency[tile]) do
                if Adjacency[nb] then
                    SwapRemove(Adjacency[nb], tile)
                end
            end
            Adjacency[tile] = nil
        end

        TileIndex[tile] = nil
        TileCount -= 1
        BoundsDirty = true
    end

    local function DisconnectAll()
        for _, c in next, ConnColor do
            c:Disconnect()
        end

        for _, c in next, ConnDesc do
            c:Disconnect()
        end

        for _, c in next, ConnText do
            c:Disconnect()
        end

        for _, cs in next, ConnFlag do
            for _, c in ipairs(cs) do
                c:Disconnect()
            end
        end

        ConnColor, ConnDesc, ConnText, ConnFlag = {}, {}, {}, {}
    end

    local function SetupCore()
        if not GameRunning.Value then
            return
        end

        EnsureVizFolder()
        DisconnectAll()

        Adjacency, TileIndex, Grid = {}, {}, {}
        TileCount, LastSig, BoardBounds, BoundsDirty = 0, nil, nil, true

        GridW, GridH, TileStep, SettingsObj = ReadSettings()
        TotalTiles = GridW and GridH and GridW * GridH or nil

        if MinesVal then
            TotalMines = MinesVal.Value
        end

        ClearAllCore()

        for _, t in ipairs(Parts:GetChildren()) do
            RegisterTile(t, true)
        end

        QueueSolveCore(true)
    end

    local function FullCleanupCore()
        ClearAllCore()
        DisconnectAll()

        for _, c in ipairs(ConnTop) do
            c:Disconnect()
        end

        ConnTop = {}

        for _, p in ipairs(Pool) do
            p:Destroy()
        end

        Pool = {}

        Adjacency, TileIndex, Grid = {}, {}, {}
        BoardBounds, LastSig = nil, nil

        if VizFolder and VizFolder.Parent then
            VizFolder:Destroy()
        end

        VizFolder = nil

        _G.CleanupUltraSolver = nil
        _G.UltraSolverInfo = nil
    end

    local function RefreshStatusCore()
        if not StatusOutput then
            return
        end

        local overlayCount = 0
        for _ in next, Overlays do
            overlayCount += 1
        end

        local poolCount = #Pool

        local info = _G.UltraSolverInfo and _G.UltraSolverInfo() or {}

        local gridText = "Unknown"
        if info.GridSize then
            gridText = string.format("%d x %d", info.GridSize.X, info.GridSize.Z)
        end

        local densityText = "Unknown"
        if info.Density then
            densityText = string.format("%.4f", info.Density)
        end

        local bestText = "None"
        if LastBestTile and LastBestTile.Parent then
            bestText = LastBestTile.Name
        end

        local bestProbText = "None"
        if LastSolveInfo and LastSolveInfo.BestProbability and LastSolveInfo.BestProbability ~= math.huge then
            bestProbText = string.format("%.4f", LastSolveInfo.BestProbability)
        end

        local ageText = "Never"
        if LastSolveInfo and LastSolveInfo.Time then
            ageText = string.format("%.2fs ago", math.max(0, os.clock() - LastSolveInfo.Time))
        end

        local lines = {
            "Core: " .. (CoreReady and "Ready" or "Initializing"),
            "Game Running: " .. tostring(GameRunning.Value),
            "Solver Enabled: " .. tostring(CFG.Enabled),
            "Auto Solve: " .. tostring(CFG.AutoSolve),
            "Visuals Enabled: " .. tostring(CFG.VisualsEnabled),
            "",
            "Grid Size: " .. gridText,
            "Tile Count: " .. tostring(info.TileCount or TileCount),
            "Total Expected Tiles: " .. tostring(info.TotalExpectedTiles or TotalTiles or "Unknown"),
            "Total Mines: " .. tostring(TotalMines),
            "Density: " .. densityText,
            "",
            "Overlays: " .. tostring(overlayCount),
            "Pool: " .. tostring(poolCount),
            "Last Solve: " .. ageText,
            "Best Tile: " .. bestText,
            "Best Probability: " .. bestProbText,
        }

        if LastSolveInfo and LastSolveInfo.Unknown ~= nil then
            table.insert(lines, "Unknown Tiles: " .. tostring(LastSolveInfo.Unknown))
        end

        if LastSolveInfo and LastSolveInfo.Constraints ~= nil then
            table.insert(lines, "Constraints: " .. tostring(LastSolveInfo.Constraints))
        end

        if LastSolveInfo and LastSolveInfo.Partitions ~= nil then
            table.insert(lines, "Partitions: " .. tostring(LastSolveInfo.Partitions))
        end

        if LastSolveInfo and LastSolveInfo.FailedPartitions ~= nil then
            table.insert(lines, "Failed Partitions: " .. tostring(LastSolveInfo.FailedPartitions))
        end

        pcall(function()
            StatusOutput:SetDesc(table.concat(lines, "\n"))
        end)
    end

    -- ─── GLOBAL API ─────────────────────────────────────
    _G.CleanupUltraSolver = FullCleanupCore

    _G.UltraSolverInfo = function()
        return {
            GridSize = GridW and GridH and { X = GridW, Z = GridH } or nil,
            TileSize = TileStep,
            TotalExpectedTiles = TotalTiles,
            Density = TotalTiles and (TotalMines / TotalTiles) or nil,
            TileCount = TileCount,
        }
    end

    -- ─── LIFECYCLE CONNECTIONS ──────────────────────────
    ConnTop[#ConnTop + 1] = Parts.ChildAdded:Connect(function(c)
        RegisterTile(c, false)
    end)

    ConnTop[#ConnTop + 1] = Parts.ChildRemoved:Connect(UnregisterTile)

    ConnTop[#ConnTop + 1] = GameRunning:GetPropertyChangedSignal("Value"):Connect(function()
        if GameRunning.Value then
            if CFG.AutoSetup then
                SetupCore()
            else
                QueueSolveCore(true)
            end
        else
            LastSig = nil
            ClearAllCore()
        end
    end)

    if MinesVal then
        ConnTop[#ConnTop + 1] = MinesVal:GetPropertyChangedSignal("Value"):Connect(function()
            QueueSolveCore(false)
        end)
    end

    if SettingsObj then
        ConnTop[#ConnTop + 1] = SettingsObj.AttributeChanged:Connect(function(attr)
            if (attr == "GridSize" or attr == "GridSizeX" or attr == "GridSizeZ" or attr == "TileSize")
                and GameRunning.Value
            then
                SetupCore()
            end
        end)
    end

    -- Expose to UI
    Setup = SetupCore
    QueueSolve = function(force)
        QueueSolveCore(force == true)
    end
    ClearAll = ClearAllCore
    Cleanup = FullCleanupCore
    RefreshStatus = RefreshStatusCore
    ForceSolve = function()
        QueueSolveCore(true)
    end
    GetBestTile = function()
        return LastBestTile
    end

    CoreReady = true

    if GameRunning.Value and CFG.AutoSetup then
        SetupCore()
    end
end)

if not ok then
    CoreError = tostring(err)
    CoreReady = false

    warn("[BlockermanSolver] Core initialization failed: " .. CoreError)

    pcall(function()
        StatusOutput:SetDesc("Core failed to initialize:\n" .. CoreError)
    end)

    WindUI:Notify({
        Title = "Core Error",
        Content = "Solver core failed to initialize. Check Problems tab and game instances.",
        Icon = "alert-triangle",
        Duration = 8,
    })
end
