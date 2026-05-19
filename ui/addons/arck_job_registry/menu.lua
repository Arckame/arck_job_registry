-- ARCK - Job Registry (ARCK-JR)

local ffi = require("ffi")
local C = ffi.C
pcall(ffi.cdef, [[
    typedef uint64_t UniverseID;
    int32_t GetEntityCombinedSkill(UniverseID entityid, const char* role, const char* postid);
    void SetGuidance(UniverseID componentid, UIPosRot offset);
    void EndGuidance(void);
]])

local menu = {
    name = "Arckame_JobRegistry_Menu",
    updateInterval = 0.1,
    infoFrame = nil,
    personnel  = {},
    sortColumn = nil,
    sortDirection = -1,
}

local config = {
    width    = 1000,
    maxListH = 400,
    layer    = 2,   
}

-- Sort table
local function onSortColumn(column)
    if menu.sortColumn == column then
        menu.sortDirection = -menu.sortDirection
    else
        menu.sortColumn = column
        menu.sortDirection = -1
    end
    menu.createInfoFrame()
end

-- Load NPC list
local function loadPersonnel()
    menu.personnel = {}
    local stationID = menu.param and menu.param[1]

    -- Debug and Return if no stationID
    if not stationID then
        DebugError("[ARCK-JR] loadPersonnel: missing param[1]")
        return
    end
    local stationUID = ConvertIDTo64Bit(stationID)
    local stationOwner = GetComponentData(stationUID, "owner")
    local npctable = GetNPCs(stationUID)
    
    -- Preparing NPC list
    for _, npc in ipairs(npctable) do
        local npcUID = ConvertIDTo64Bit(npc)
        local typestr, isPlayerOwned, name, owner, skills = GetComponentData(npcUID, "typestring", "isplayerowned", "name", "owner", "skills")

        -- Add NPC Data to list
        if typestr == "crowd" 
            and name 
            and name ~= "" 
            and owner == stationOwner
            and GetNPCBlackboard(npcUID, "$HiringFee") ~= nil
            then
            table.insert(menu.personnel, {
                uid     = npcUID,
                name    = name,
                pilot   = skills[5]["value"],
                manager = skills[3]["value"],
                marine  = skills[1]["value"],
                service = skills[2]["value"],
                fee     = (not isPlayerOwned) and GetNPCBlackboard(npcUID, "$HiringFee") or nil,
                moral   = skills[4]["value"]
            })
        end
    end
end

-- Menu cleanup
function menu.cleanup()
    menu.infoFrame = nil
    menu.personnel = {}
end

-- Menu frame
function menu.createInfoFrame()
    
    Helper.clearDataForRefresh(menu, config.layer)
    local bSize      = tonumber(Helper.borderSize)
    local vWidth     = tonumber(Helper.viewWidth)
    local vHeight    = tonumber(Helper.viewHeight)
    local scaledW    = tonumber(Helper.scaleX(config.width))
    local scaledMaxH = math.min(tonumber(Helper.scaleY(config.maxListH)), vHeight * 0.8)

    local frameProperties = {
        standardButtons = {},
        width  = scaledW + 6 * bSize,
        x      = (vWidth - scaledW) / 2,
        y      = 0,
        layer  = config.layer,
        startAnimation = false,
    }

    menu.infoFrame = Helper.createFrameHandle(menu, frameProperties)
    menu.infoFrame:setBackground("solid", { color = Color["frame_background_semitransparent"] })

    local tableProperties = {
        width = scaledW,
        x     = 3 * bSize,
        y     = 3 * bSize,
    }

    local ftable = menu.createTable(menu.infoFrame, tableProperties, scaledMaxH)
    menu.infoFrame.properties.height = tonumber(ftable.properties.y) + tonumber(ftable:getVisibleHeight()) + 3 * bSize
    menu.infoFrame.properties.y      = (vHeight - menu.infoFrame.properties.height) / 2
    menu.infoFrame:display()
end

-- Table
function menu.createTable(frame, tableProperties, scaledMaxH)
    local NCOLS = 8
    local ftable = frame:addTable(NCOLS, {
        tabOrder             = 2,   -- ≠ 1 : évite que helper.lua lise menu.param[1] comme toprow
        width                = tonumber(tableProperties.width),
        x                    = tonumber(tableProperties.x),
        y                    = tonumber(tableProperties.y),
        maxVisibleHeight     = scaledMaxH,
        defaultInteractiveObject = true,
        reserveScrollBar     = true,
    })

    -- Set column widths
    -- ftable:setColWidthPercent(1, 30)
    ftable:setColWidthPercent(2, 10)
    ftable:setColWidthPercent(3, 10)
    ftable:setColWidthPercent(4, 10)
    ftable:setColWidthPercent(5, 10)
    ftable:setColWidthPercent(6, 10)
    ftable:setColWidthPercent(7, 10)
    ftable:setColWidthPercent(8, 6)

    -- Title (span all columns)
    local row = ftable:addRow(false, {})
    row[1]:setColSpan(NCOLS):createText(ReadText(75200, 2), Helper.headerRowCenteredProperties)

    -- Header
    local hrow = ftable:addRow(true, { })
    hrow[1]:createText(ReadText(1001, 9145), { halign = "left", fontsize = Helper.headerFontSize })
    
    local skillCols = {
        { idx = 2, col = "fee", label = "Fee" },
        { idx = 3, col = "pilot", label = ReadText(1013, 501) },
        { idx = 4, col = "manager", label = ReadText(1013, 301) },
        { idx = 5, col = "marine", label = ReadText(1013, 101) },
        { idx = 6, col = "service", label = ReadText(1013, 201) },
        { idx = 7, col = "moral", label = ReadText(1013, 401) },
    }

    -- Building sortable headers with icons
    for _, sc in ipairs(skillCols) do
        local btn = hrow[sc.idx]:createButton({})
        if menu.sortColumn == sc.col then
            local icon = menu.sortDirection == -1 and "\27[widget_arrow_down_01]" or "\27[widget_arrow_up_01]"
            btn:setText(sc.label .. icon, { halign = "center" })
        else
            btn:setText(sc.label, { halign = "center" })
        end
        
        local col = sc.col
        hrow[sc.idx].handlers.onClick = function() onSortColumn(col) end
    end

    hrow[8]:createText("",          { halign = "center", fontsize = Helper.headerFontSize })
    
    -- Separator line
    local row = ftable:addRow(false, {})
    row[1]:setColSpan(NCOLS):createText("")

    -- Data
    if #menu.personnel == 0 then
        local row = ftable:addRow(false, {})
        row[1]:setColSpan(NCOLS):createText("Aucun personnel disponible.", { halign = "center" })
    else
        if menu.sortColumn then
            table.sort(menu.personnel, function(a, b)
                local va = tonumber(a[menu.sortColumn]) or 0
                local vb = tonumber(b[menu.sortColumn]) or 0
                if va ~= vb then
                    if menu.sortDirection == -1
                    then return va > vb end
                    return va < vb
                end
                return a.name < b.name
            end)
        end

        for _, p in ipairs(menu.personnel) do
            local pUID = p.uid   -- capture locale pour le handler
            local row = ftable:addRow(true, {})
            row[1]:createText(p.name, { halign = "left" })
            row[2]:createText(p.fee and (ConvertMoneyString(tonumber(p.fee) or 0, false, true, 0, true) .. " Cr") or "-", { halign = "right" })
            row[3]:createText(tostring(Helper.displaySkill(tonumber(p.pilot) or 0)), { halign = "center", color = Color["text_skills"] })
            row[4]:createText(tostring(Helper.displaySkill(tonumber(p.manager) or 0)), { halign = "center", color = Color["text_skills"] })
            row[5]:createText(tostring(Helper.displaySkill(tonumber(p.marine) or 0)), { halign = "center", color = Color["text_skills"] })
            row[6]:createText(tostring(Helper.displaySkill(tonumber(p.service) or 0)), { halign = "center", color = Color["text_skills"] })
            row[7]:createText(tostring(Helper.displaySkill(tonumber(p.moral) or 0)), { halign = "center", color = Color["text_skills"] })
            row[8]:createButton({}):setText(ReadText(1010, 4), { halign = "center" })
            row[8].handlers.onClick = function()
                -- I keep the guidance code, just in case
                -- C.SetGuidance(pUID, ffi.new("UIPosRot"))
                -- menu.onCloseElement("back", true)
            
                -- This is the first try, was not working because thi is a subconversation, not a new conversation
                -- Helper.closeMenuForNewConversation(menu, "default", pUID, nil, true)
                Helper.closeMenuForSubConversation(menu, "default", pUID, nil)
                menu.cleanup()
            end
        end
    end

    local row = ftable:addRow(false, {})
    row[1]:setColSpan(NCOLS):createText("")

    local row = ftable:addRow(true, {})
    row[1]:setColSpan(NCOLS):createButton({}):setText(ReadText(1001, 2670), { halign = "center" })
    row[1].handlers.onClick = function()
        return menu.onCloseElement("back", true)
    end

    return ftable
end

-- On show menu trigger
function menu.onShowMenu()
    loadPersonnel()
    menu.createInfoFrame()
end

-- On show menu sound trigger
function menu.onShowMenuSound()
    -- pas de son
end

-- On view created trigger
function menu.viewCreated(layer, ...)
end

-- On update trigger
function menu.onUpdate()
    if menu.infoFrame then
        menu.infoFrame:update()
    end
end

-- On row changed trigger
function menu.onRowChanged(row, rowdata, uitable)
end

-- On select element trigger
function menu.onSelectElement(uitable, modified, row)
end

-- On close element trigger
function menu.onCloseElement(dueToClose, allowAutoMenu)
    Helper.closeMenuAndReturn(menu)
    menu.cleanup()
end

-- Init function
local function init()
    Menus = Menus or {}
    table.insert(Menus, menu)
    if Helper then
        Helper.registerMenu(menu)
    end
end

-- Init call
init()
