GLOBAL.setmetatable(env, {
    __index = function(_, k)
        return GLOBAL.rawget(GLOBAL, k)
    end
})

local function IsDefaultScreen()
    local active_screen = GLOBAL.TheFrontEnd:GetActiveScreen()
    local screen = active_screen and active_screen.name or ""
    return screen:find("HUD") ~= nil and GLOBAL.ThePlayer ~= nil and not GLOBAL.ThePlayer.HUD:IsChatInputScreenOpen() and not GLOBAL.ThePlayer.HUD.writeablescreen and not
    (ThePlayer.HUD.controls and ThePlayer.HUD.controls.craftingmenu and ThePlayer.HUD.controls.craftingmenu.craftingmenu and ThePlayer.HUD.controls.craftingmenu.craftingmenu.search_box and ThePlayer.HUD.controls.craftingmenu.craftingmenu.search_box.textbox and ThePlayer.HUD.controls.craftingmenu.craftingmenu.search_box.textbox.editing)
end

if GetModConfigData('language') == 'zh' then
    modimport('languages/Chinese.lua')
else
    modimport('languages/English.lua')
end

Assets = {
    Asset("ATLAS", "images/bspj_square.xml"),
    Asset("IMAGE", "images/bspj_square.tex"),
    Asset("ANIM", "anim/unknown_prefab.zip")
}
PrefabFiles = { 'base_projection' }

local pi = 3.141592653
local function _rotate(x, z, angle)
    if angle == 0 then
        return x, z
    end
    while angle < 0 do
        angle = angle + 360
    end
    while angle >= 360 do
        angle = angle - 360
    end
    local rau = math.sqrt(x * x + z * z)
    if rau == 0 then
        return x, z
    end
    local theta = math.acos(x / rau) / pi * 180
    if z < 0 then
        theta = 360 - theta
    end
    theta = (theta + angle) / 180 * pi
    x = rau * math.cos(theta)
    z = rau * math.sin(theta)
    return x, z
end
GLOBAL.BSPJRotate = _rotate

local auto_thread
GLOBAL.BASE_RECORD_HELPER = nil
GLOBAL.IsBSPJRecordHelperReady = function()
    return GLOBAL.BASE_RECORD_HELPER and GLOBAL.BASE_RECORD_HELPER:IsValid()
end

GLOBAL.BASE_PLAY_HELPER = nil
GLOBAL.IsBSPJPlayHelperReady = function()
    return GLOBAL.BASE_PLAY_HELPER and GLOBAL.BASE_PLAY_HELPER:IsValid()
end
local BSPJPanel = require "widgets/BSPJPanel"
local BSPJRecordPanel = BSPJPanel[1]
local BSPJPlayPanel = BSPJPanel[2]
local controls
AddClassPostConstruct("widgets/controls", function(self)
    controls = self
    if controls and controls.top_root then
        controls.BSPJRecordPanel = controls.top_root:AddChild(BSPJRecordPanel())
        controls.BSPJRecordPanel:Close()
        controls.BSPJPlayPanel = controls.top_root:AddChild(BSPJPlayPanel())
        controls.BSPJPlayPanel:Close()
    end
end)

local key_toggle_record = GetModConfigData("key_toggle_record") ~= -1 and GLOBAL[GetModConfigData("key_toggle_record")] or -1
TheInput:AddKeyUpHandler(key_toggle_record, function()
    if IsDefaultScreen() then
        if controls and controls.BSPJRecordPanel then
            if controls.BSPJRecordPanel.IsShow then
                controls.BSPJRecordPanel:Close()
            else
                controls.BSPJRecordPanel:Open()
            end
        end
    end
end)

local key_toggle_play = GetModConfigData("key_toggle_play") ~= -1 and GLOBAL[GetModConfigData("key_toggle_play")] or -1
TheInput:AddKeyUpHandler(key_toggle_play, function()
    if IsDefaultScreen() then
        if controls and controls.BSPJPlayPanel then
            if controls.BSPJPlayPanel.IsShow then
                controls.BSPJPlayPanel:Close()
            else
                controls.BSPJPlayPanel:Open()
            end
        end
    end
end)

GLOBAL.BSPJ = {
    DATA = {
        PREFAB_CAPTURE = true,
        GRID_CAPTURE = true,
        ORDER_TIPS = true,
        SHOW_NAME = false,
        GP_ADAPTION = true,
        CAPTURE_ANNOUNCE = true,
        QUICK_ANNOUNCE = 'on',
        CAPTURE_SELF = false,
        ANNOUNCE_WHISPER = false,
        SHOW_BLUE_PRINT = true,
        ANIM_VALID = false,
        ROTATE_PLACE = true,
        PRECISION = { '1/2', 0.5 },
        PLAN_PRECISION = { '1/8', 0.125 },
        AUTO_WORK = 'LSHIFT',
        BUILD_PLAN = 'F4',
        ANGLE = 0,
        RECORDS = {},
    },
    NAME = STRINGS.BSPJ.TITLE_TEXT_CUSTOMIZE,
    SEARCH_WORD = '',
    PATH = '',
    LAST_POS = nil,
    LAST_RECORD = nil,
    BLUE_PRINTS = {
        require 'blue_prints/bspj_four_four',  -- 【预设】四锅四冰箱
        require 'blue_prints/bspj_five_three',  -- 【预设】五锅三冰箱
        require 'blue_prints/bspj_six',  -- 【预设】六锅
        require 'blue_prints/bspj_dog',  -- 【预设】狗王工厂
        require 'blue_prints/bspj_pig',  -- 【预设】猪人工厂
        require 'blue_prints/bspj_thief',  -- 【预设】小偷包工厂
        require 'blue_prints/bspj_single',  -- 【预设】单灭火器建家
        require 'blue_prints/bspj_boat_seven',  -- 【预设】单船7投石器
        require 'blue_prints/bspj_one_nine',  -- 【预设】1发电机9投石器
    },
    ANNOUNCEMENTS = {},
    is_build_planing = false
}
local DATA_FILE = "mod_config_data/nomu_bspj_save_v2"
local LAST_FILE = "mod_config_data/nomu_bspj_save_v2_" .. TheNet:GetSessionIdentifier()

GLOBAL.BSPJ.LoadData = function()
    TheSim:GetPersistentString(DATA_FILE, function(load_success, str)
        if load_success and #str > 0 then
            local run_success, data = RunInSandboxSafe(str)
            if run_success then
                for k, v in pairs(data) do
                    if v ~= nil then
                        GLOBAL.BSPJ.DATA[k] = v
                    end
                end
                if GLOBAL.BSPJ.DATA.QUICK_ANNOUNCE == true then
                    GLOBAL.BSPJ.DATA.QUICK_ANNOUNCE = 'on'
                elseif GLOBAL.BSPJ.DATA.QUICK_ANNOUNCE == false then
                    GLOBAL.BSPJ.DATA.QUICK_ANNOUNCE = 'off'
                end
            end
        end
    end)

    TheSim:GetPersistentString(LAST_FILE, function(load_success, str)
        if load_success and #str > 0 then
            local run_success, data = RunInSandboxSafe(str)
            if run_success then
                GLOBAL.BSPJ.LAST_POS = data and data.LAST_POS or GLOBAL.BSPJ.LAST_POS
                GLOBAL.BSPJ.LAST_RECORD = data and data.LAST_RECORD or GLOBAL.BSPJ.LAST_RECORD
            end
        end
    end)
end

GLOBAL.BSPJ.SaveData = function()
    SavePersistentString(DATA_FILE, DataDumper(GLOBAL.BSPJ.DATA, nil, true), false, nil)
end

GLOBAL.BSPJ.SaveLast = function()
    SavePersistentString(LAST_FILE, DataDumper({ LAST_POS = GLOBAL.BSPJ.LAST_POS, LAST_RECORD = GLOBAL.BSPJ.LAST_RECORD }, nil, true), false, nil)
end

AddSimPostInit(function()
    GLOBAL.BSPJ.LoadData()
end)

------------------------------------------------------------------------------------
local last_best_anchor
local anchor_pos

local oldIsKeyDown = TheInput.IsKeyDown
GLOBAL.BSPJOldIsKeyDown = oldIsKeyDown
local gp_mod = ModManager:GetMod("workshop-351325790")
local gpCanBuildAtPoint
local function ShouldPressCtrl()
    if gp_mod and gpCanBuildAtPoint then
        local name, value = debug.getupvalue(gpCanBuildAtPoint, 1)
        if name == 'CTRL' then
            return not value
        end
    end
    return true
end

local function IsBSPJRecordEnable()
    return IsDefaultScreen() and controls and controls.BSPJRecordPanel and controls.BSPJRecordPanel.IsShow
end

local function IsBSPJPlayEnable()
    return IsDefaultScreen() and controls and controls.BSPJPlayPanel and controls.BSPJPlayPanel.IsShow
end

-- 投影基地时禁用官方网格辅助
AddClassPostConstruct("components/placer", function(self)
    local old_Placer_IsAxisAlignedPlacement = self.IsAxisAlignedPlacement
    self.IsAxisAlignedPlacement = function(self, ...)
        if IsBSPJPlayEnable() and GLOBAL.IsBSPJPlayHelperReady() then
            return false
        end
        return old_Placer_IsAxisAlignedPlacement(self, ...)
    end
end)

GLOBAL.BSPJGetTurfCenter = function(px, py, pz)
    local x, y = TheWorld.Map:GetTileCoordsAtPoint(px, py, pz)
    local width, height = TheWorld.Map:GetSize()
    local spawn_x, spawn_z = (x - width / 2.0) * TILE_SCALE, (y - height / 2.0) * TILE_SCALE
    return spawn_x, 0, spawn_z
end

GLOBAL.BSPJSnapToGrid = function(x, y, z, precision)
    precision = precision or BSPJ.DATA.PRECISION[2]
    if precision == 0 then
        return x, y, z
    end
    local sx, _, sz = GLOBAL.BSPJGetTurfCenter(x, 0, z)
    local d = TILE_SCALE * precision
    x = math.floor((x - sx) / d + 0.5) * d + sx
    z = math.floor((z - sz) / d + 0.5) * d + sz
    return x, y, z
end

local function IsBuildPlanning()
    --return oldIsKeyDown(TheInput, GLOBAL['KEY_' .. BSPJ.DATA.BUILD_PLAN])
    return IsBSPJPlayEnable() and GLOBAL.IsBSPJPlayHelperReady() and GLOBAL.BSPJ.is_build_planing
end

local function _insert_placer(name, prefab, placer, px, py, pz, is_wall, no_snap, rotation)
    if placer and placer:IsValid() then
        local last_record = BSPJ.LAST_RECORD
        local reset = true
        for _ in pairs(BASE_PLAY_HELPER.anchors) do
            reset = false
            break
        end
        local bx, by, bz = BASE_PLAY_HELPER:GetPosition():Get()
        if last_record == nil or reset then
            last_record = { name = STRINGS.BSPJ.BUTTON_TEXT_BUILD_PLAN, data = {}, x = bx, y = by, z = bz }
        end
        local cx, cy, cz = last_record.x, last_record.y, last_record.z
        local build = placer.AnimState:GetBuild()
        local bank = placer.AnimState:GetCurrentBankName()
        local _, anim = placer.AnimState:GetHistoryData()
        local sx, sy, sz = placer.Transform:GetScale()
        rotation = rotation or placer.Transform:GetFacingRotation()
        local layer = placer.AnimState:GetLayer()
        if placer.components and placer.components.placer and placer.components.placer.onground then
            layer = 5
        end
        if not no_snap then
            if is_wall then
                px = math.floor(px) + .5
                pz = math.floor(pz) + .5
            else
                px, py, pz = GLOBAL.BSPJSnapToGrid(px, py, pz, BSPJ.DATA.PLAN_PRECISION[2])
            end
        end
        local x, y, z = px - bx + cx, py - by + cy, pz - bz + cz
        x, z = _rotate(x - cx, z - cz, -BSPJ.DATA.ANGLE)
        table.insert(last_record.data, {
            name = name, prefab = prefab, x = x + cx, y = y, z = z + cz,
            build = build, bank = bank, anim = anim, scale = { sx, sy, sz },
            rotation = rotation, layer = layer
        })
        BASE_PLAY_HELPER:SetRecord(last_record)

        --local flag = true
        --for _, i in ipairs(last_record.data) do
        --    if i.prefab == prefab and i.x == x + cx and i.y == y and i.z == z + cz and i.name == name then
        --        --and SPACING_DICT[prefab] ~= 0 then
        --        flag = false
        --        break
        --    end
        --end
        --if flag then
        --    table.insert(last_record.data, {
        --        name = name, prefab = prefab, x = x + cx, y = y, z = z + cz,
        --        build = build, bank = bank, anim = anim, scale = { sx, sy, sz },
        --        rotation = rotation, layer = layer
        --    })
        --    BASE_PLAY_HELPER:SetRecord(last_record)
        --end
    end
end

AddClassPostConstruct("components/builder_replica", function(Builder)
    local OldCanBuildAtPoint = Builder.CanBuildAtPoint
    if gp_mod then
        gpCanBuildAtPoint = OldCanBuildAtPoint
    end

    local oldIsFreeBuildMode = Builder.IsFreeBuildMode
    Builder.IsFreeBuildMode = function(...)
        if IsBuildPlanning() then
            return true
        end
        return oldIsFreeBuildMode(...)
    end

    local oldHasIngredients = Builder.HasIngredients
    Builder.HasIngredients = function(self, recipe, ...)
        if IsBuildPlanning() then
            if type(recipe) ~= "string" then
                recipe = recipe.name
            end
            return AllRecipes[recipe].placer ~= nil
        end
        return oldHasIngredients(self, recipe, ...)
    end

    local oldIsBuildBuffered = Builder.IsBuildBuffered
    Builder.IsBuildBuffered = function(self, recipename, ...)
        if IsBuildPlanning() then
            return AllRecipes[recipename].placer ~= nil
        end
        return oldIsBuildBuffered(self, recipename, ...)
    end

    local oldMakeRecipeAtPoint = Builder.MakeRecipeAtPoint
    Builder.MakeRecipeAtPoint = function(self, recipe, pt, rot, skin, ...)
        if IsBuildPlanning() then
            local placer = SpawnPrefab(recipe.placer)
            _insert_placer(STRINGS.NAMES[recipe.name:upper()] or recipe.name, recipe.name, placer, pt.x, pt.y, pt.z, nil, nil, rot)
            placer:Remove()
            ThePlayer:DoTaskInTime(0, function()
                ThePlayer.components.playercontroller:StartBuildPlacementMode(recipe, skin)
            end)
            return
        end
        return oldMakeRecipeAtPoint(self, recipe, pt, rot, skin, ...)
    end
end)

GLOBAL.BSPJSendCommand = function(cmd)
    local x, _, z = TheSim:ProjectScreenPos(TheSim:GetPosition())
    if TheNet:GetIsClient() and TheNet:GetIsServerAdmin() then
        TheNet:SendRemoteExecute(cmd, x, z)
    else
        ExecuteConsoleCommand(cmd)
    end
end
local DEPLOY_DICT = require("utils/deploys")
GLOBAL.BSPJGetDeployablePrefabs = function()
    BSPJSendCommand(DEPLOY_DICT.bspj_cmd)
end
local function PlanningAtPos(act_type, px, pz)
    local placer, prefab, name, is_wall, no_snap, rotation
    local delete_placer = false
    if act_type == 'deploy' then
        local item = ThePlayer.replica.inventory:GetActiveItem()
        if item and item.prefab then
            prefab = DEPLOY_DICT[item.prefab] or (item.prefab .. '_placer')
            local controller = ThePlayer.components.playercontroller
            if controller.deployplacer and controller.deployplacer.GetRotation then
                placer = controller.deployplacer
                rotation = controller.deployplacer.Transform:GetRotation()
            else
                placer = SpawnPrefab(item.prefab .. '_placer')
                delete_placer = true
            end
            if item.replica and item.replica.inventoryitem and item.replica.inventoryitem.classified.deploymode then
                is_wall = item.replica.inventoryitem.classified.deploymode:value() == DEPLOYMODE.WALL
            end
        end
    else
        placer = ThePlayer.replica.inventory:GetActiveItem()
        if placer and placer.prefab then
            prefab = placer.prefab
            name = placer.GetBasicDisplayName and placer:GetBasicDisplayName() or placer:GetDisplayName()
            no_snap = true
        end
    end
    if placer and prefab then
        _insert_placer(name or STRINGS.NAMES[prefab:upper()] or prefab, prefab, placer, px, 0, pz, is_wall, no_snap, rotation)
    end
    if delete_placer and placer then
        placer:Remove()
    end
end

TheInput.IsKeyDown = function(self, key, ...)
    if GLOBAL.BSPJ.DATA.GP_ADAPTION and key == GLOBAL.KEY_CTRL and gp_mod and (anchor_pos or auto_thread) and IsBSPJPlayEnable() and GLOBAL.IsBSPJPlayHelperReady() then
        return ShouldPressCtrl()
    end
    return oldIsKeyDown(self, key, ...)
end

local function GetOrCapturePos()
    local entity = ConsoleWorldEntityUnderMouse()
    local x, z
    if BSPJ.DATA.PREFAB_CAPTURE and (entity and entity:IsValid() and entity.prefab and entity.Transform) then
        x, _, z = entity:GetPosition():Get()
    else
        x, _, z = TheInput:GetWorldPosition():Get()
        if BSPJ.DATA.GRID_CAPTURE then
            x, _, z = GLOBAL.BSPJSnapToGrid(x, 0, z)
        end
    end
    return x, 0, z
end

local _cc
local function GetOrCreateCenter()
    if _cc and _cc:IsValid() then
        return _cc
    end
    _cc = SpawnPrefab('base_center')
    return _cc
end

local oldGetWorldPosition = TheInput.GetWorldPosition
GLOBAL.BSPJOldGetWorldPosition = oldGetWorldPosition
TheInput.GetWorldPosition = function(self)
    if anchor_pos then
        return anchor_pos
    end
    return oldGetWorldPosition(self)
end

------------------------------------------------------------------------------------

local GeoUtil = require("utils/geoutil")
local Image = require("widgets/image")
local unselectable_tags = { "DECOR", "FX", "INLIMBO", "NOCLICK", "player" }
local last_click = { time = 0 }
local double_click_speed = 0.4
local double_click_range = 15
local selection_thread
local selection_thread_id = "bspj_selection_thread"
local _screen_x, _screen_y
local _queued_movement = false
local _selection_widget
TheInput:AddMoveHandler(function(x, y)
    _screen_x, _screen_y = x, y
    _queued_movement = true
end)
local function ClearSelectionThread()
    if selection_thread then
        KillThreadsWithID(selection_thread.id)
        selection_thread:SetList(nil)
        selection_thread = nil
        if _selection_widget then
            _selection_widget:Hide()
        end
    end
end

local function GetWorldPosition(screen_x, screen_y)
    return Point(TheSim:ProjectScreenPos(screen_x, screen_y))
end

local function BoxSelect()
    local previous_ents = {}
    local started_selection = false
    local start_x, start_y = _screen_x, _screen_y
    if not _selection_widget then
        _selection_widget = Image("images/bspj_square.xml", "bspj_square.tex")
        _selection_widget:SetTint(0, 1, 0, 0.5)
        _selection_widget:Hide()
    end
    local _TL, _BL, _TR, _BR
    local function update_selection()
        if not started_selection then
            if math.abs(start_x - _screen_x) + math.abs(start_y - _screen_y) < 32 then
                return
            end
            started_selection = true
        end
        local xmin, xmax = start_x, _screen_x
        if xmax < xmin then
            xmin, xmax = xmax, xmin
        end
        local ymin, ymax = start_y, _screen_y
        if ymax < ymin then
            ymin, ymax = ymax, ymin
        end
        _selection_widget:SetPosition((xmin + xmax) / 2, (ymin + ymax) / 2)
        _selection_widget:SetSize(xmax - xmin + 2, ymax - ymin + 2)
        _selection_widget:Show()
        _TL, _BL, _TR, _BR = GetWorldPosition(xmin, ymax), GetWorldPosition(xmin, ymin), GetWorldPosition(xmax, ymax), GetWorldPosition(xmax, ymin)
        local center = GetWorldPosition((xmin + xmax) / 2, (ymin + ymax) / 2)
        local range = math.sqrt(math.max(center:DistSq(_TL), center:DistSq(_BL), center:DistSq(_TR), center:DistSq(_BR)))
        local IsBounded = GeoUtil.NewQuadrilateralTester(_TL, _TR, _BR, _BL)
        local current_ents = {}
        for _, ent in pairs(TheSim:FindEntities(center.x, 0, center.z, range, nil, unselectable_tags)) do
            if ent and ent.Transform and ent:IsValid() and not ent:HasTag("INLIMBO") and ent.AnimState then
                local pos = ent:GetPosition()
                if IsBounded(pos) then
                    if not GLOBAL.BASE_RECORD_HELPER.anchors[ent] and not previous_ents[ent] then
                        GLOBAL.BASE_RECORD_HELPER:SelectTarget(ent)
                    end
                    current_ents[ent] = true
                end
            end
        end
        for ent in pairs(previous_ents) do
            if not current_ents[ent] then
                GLOBAL.BASE_RECORD_HELPER:DeselectTarget(ent)
            end
        end
        previous_ents = current_ents
    end
    selection_thread = StartThread(function()
        while IsBSPJRecordEnable() and GLOBAL.IsBSPJRecordHelperReady() do
            if _queued_movement then
                update_selection()
                _queued_movement = false
            end
            Sleep(FRAMES)
        end
        ClearSelectionThread()
    end, selection_thread_id)
end

------------------------------------------------------------------------------------

local action_delay = FRAMES * 3
local work_delay = FRAMES * 6
local _prefab, _act_type
local preview_prefabs = {}
GLOBAL.BSPJClearPreviews = function()
    for _, inst in ipairs(preview_prefabs) do
        inst:Remove()
    end
    preview_prefabs = {}
    _prefab = nil
    _act_type = nil
    if GLOBAL.IsBSPJPlayHelperReady() then
        for anchor in pairs(GLOBAL.BASE_PLAY_HELPER.anchors) do
            anchor.AnimState:SetAddColour(0, 0, 0, 0)
        end
    end
end

TheInput:AddKeyHandler(function(key, down)
    if key == GLOBAL['KEY_' .. BSPJ.DATA.AUTO_WORK] and not down then
        if auto_thread == nil then
            GLOBAL.BSPJClearPreviews()
        end
    end
    if key == GLOBAL['KEY_' .. BSPJ.DATA.BUILD_PLAN] and IsBSPJPlayEnable() and GLOBAL.IsBSPJPlayHelperReady() then
        if down then
            GLOBAL.BSPJ.is_build_planing = not GLOBAL.BSPJ.is_build_planing
            if GLOBAL.BSPJ.is_build_planing then
                for anchor in pairs(GLOBAL.BASE_PLAY_HELPER.anchors) do
                    anchor:RemoveTag('CLASSIFIED')
                    anchor:RemoveTag('NOCLICK')
                end
            else
                for anchor in pairs(GLOBAL.BASE_PLAY_HELPER.anchors) do
                    anchor:AddTag('CLASSIFIED')
                    anchor:AddTag('NOCLICK')
                end
            end
            controls.BSPJPlayPanel:UpdateTitle()
            ThePlayer:PushEvent('refreshcrafting')
        end
    end
end)

local function SpawnPreviews(prefab, act_type, prefab_inst)
    if #preview_prefabs > 0 then
        GLOBAL.BSPJClearPreviews()
    end
    if GLOBAL.IsBSPJPlayHelperReady() then
        local start_anchor = anchor_pos and last_best_anchor
        --local best_d = 1
        --local mouse_pos = TheInput:GetWorldPosition()
        --for anchor in pairs(GLOBAL.BASE_PLAY_HELPER.anchors) do
        --    local d = mouse_pos:Dist(anchor:GetPosition())
        --    if not best_d or d < best_d then
        --        start_anchor = anchor
        --        best_d = d
        --    end
        --end

        if start_anchor then
            local controller = ThePlayer.components.playercontroller
            local selected_pos
            if act_type == 'BUILD' then
                if controller.placer_recipe ~= nil and controller.placer ~= nil then
                    selected_pos = controller.placer.components.placer.selected_pos
                end
            end
            for anchor in pairs(GLOBAL.BASE_PLAY_HELPER.anchors) do
                if anchor.record_prefab == start_anchor.record_prefab then
                    local can_spawn = true
                    local pos = anchor:GetPosition()
                    local rotation = anchor.record_item.rotation
                    local preview_prefab = prefab
                    if act_type == 'DEPLOY' then
                        local act = ThePlayer.components.playeractionpicker:GetRightClickActions(pos)[1]
                        if not act or act.action ~= ACTIONS.DEPLOY then
                            can_spawn = false
                        elseif controller.deployplacer then
                            preview_prefab = SpawnSaveRecord(controller.deployplacer:GetSaveRecord())
                        else
                            preview_prefab = prefab .. '_placer'
                        end
                    elseif act_type == 'DROP' then
                        local act = ThePlayer.components.playeractionpicker:GetLeftClickActions(pos)[1]
                        if not act or act.action ~= ACTIONS.DROP then
                            can_spawn = false
                        elseif prefab_inst then
                            preview_prefab = SpawnSaveRecord(prefab_inst:GetSaveRecord())
                        end
                    elseif act_type == 'BUILD' then
                        if controller.placer_recipe ~= nil and controller.placer ~= nil then
                            controller.placer.components.placer.selected_pos = pos
                            controller.placer.components.placer:OnUpdate()
                            can_spawn = controller.placer.components.placer.can_build
                            if can_spawn then
                                preview_prefab = SpawnSaveRecord(controller.placer:GetSaveRecord())
                            end
                        end
                    end
                    if can_spawn and preview_prefab then
                        local placer
                        if type(preview_prefab) == 'string' then
                            placer = SpawnPrefab(preview_prefab)
                        else
                            placer = preview_prefab
                        end
                        if placer then
                            if rotation and rotation ~= 0 then
                                if math.fmod(rotation, 60) == 0 then
                                    placer.Transform:SetSixFaced()
                                else
                                    placer.Transform:SetEightFaced()
                                end
                                placer.Transform:SetRotation(rotation or 0)
                            end
                            placer.rotation = rotation
                            placer:RemoveComponent('placer')
                            placer:RemoveTag('CLASSIFIED')
                            placer.Transform:SetPosition(pos:Get())
                            placer.AnimState:SetAddColour(0, 0.5, 0, 0)
                            if anchor == start_anchor then
                                table.insert(preview_prefabs, 1, placer)
                            else
                                table.insert(preview_prefabs, placer)
                            end
                        end
                    --else
                    --anchor.AnimState:SetAddColour(1, 0, 0, 1)
                    end
                end
            end

            if act_type == 'BUILD' then
                if controller.placer_recipe ~= nil and controller.placer ~= nil then
                    controller.placer.components.placer.selected_pos = selected_pos
                    controller.placer.components.placer:OnUpdate()
                end
            end
        end

        if #preview_prefabs > 0 then
            for _, placer in ipairs(preview_prefabs) do
                placer:AddTag('CLASSIFIED')
                placer:AddTag('NOCLICK')
            end
            _prefab = prefab
            _act_type = act_type
        end
    end
end

local function MoveActiveItem(prefab)
    if not prefab or ThePlayer.replica.inventory:GetActiveItem() then
        return
    end
    local inventory = ThePlayer.replica.inventory
    local body_item = inventory:GetEquippedItem(EQUIPSLOTS.BODY)
    local backpack = body_item and body_item.replica.container
    for _, inv in pairs(backpack and { inventory, backpack } or { inventory }) do
        for slot, item in pairs(inv:GetItems()) do
            if item and item.prefab == prefab then
                inv:TakeActiveItemFromAllOfSlot(slot)
                return
            end
        end
    end
end

local function DoAction(act, right_click, target)
    local controller = ThePlayer.components.playercontroller
    if controller.ismastersim then
        ThePlayer.components.combat:SetTarget(nil)
        controller:DoAction(act)
        return
    end
    local pos = act:GetActionPoint() or ThePlayer:GetPosition()
    local control_mods = 10
    if controller.locomotor then
        act.preview_cb = function()
            if right_click then
                SendRPCToServer(RPC.RightClick, act.action.code, pos.x, pos.z, target, act.rotation, true, nil, nil, act.action.mod_name)
            else
                SendRPCToServer(RPC.LeftClick, act.action.code, pos.x, pos.z, target, true, control_mods, nil, act.action.mod_name)
            end
        end
        controller:DoAction(act)
    else
        if right_click then
            SendRPCToServer(RPC.RightClick, act.action.code, pos.x, pos.z, target, act.rotation, true, nil, act.action.canforce, act.action.mod_name)
        else
            SendRPCToServer(RPC.LeftClick, act.action.code, pos.x, pos.z, target, true, control_mods, act.action.canforce, act.action.mod_name)
        end
    end
end

local oldSendRPCToServer = GLOBAL.SendRPCToServer
GLOBAL.SendRPCToServer = function(code, action_code, px, pz, target, ...)
    if IsBuildPlanning() then
        if (code == RPC.RightClick and action_code == ACTIONS.DEPLOY.code) or (code == RPC.LeftClick and action_code == ACTIONS.DROP.code) then
            PlanningAtPos(action_code == ACTIONS.DROP.code and 'drop' or 'deploy', px, pz)
            --if code == RPC.RightClick then
            --    return oldSendRPCToServer(RPC.RightClick, ACTIONS.WALKTO.code, px, pz, nil, 0, true, nil, ACTIONS.WALKTO.canforce, ACTIONS.WALKTO.mod_name)
            --else
            --    return oldSendRPCToServer(RPC.LeftClick, ACTIONS.WALKTO.code, px, pz, nil, true, 10, ACTIONS.WALKTO.canforce, ACTIONS.WALKTO.mod_name)
            --end
            return
        end
    end
    return oldSendRPCToServer(code, action_code, px, pz, target, ...)
end

local function kill_auto_thread()
    if auto_thread then
        KillThreadsWithID(auto_thread.id)
        auto_thread:SetList(nil)
        auto_thread = nil
        GLOBAL.BSPJClearPreviews()
    end
end

local function SpawnPreviewsOrAutoWork(prefab, act_type, prefab_inst)
    kill_auto_thread()
    if #preview_prefabs > 0 and _prefab == prefab and _act_type == act_type then
        local sort_prefabs = { preview_prefabs[1] }
        table.remove(preview_prefabs, 1)
        while #preview_prefabs > 0 do
            local p = sort_prefabs[#sort_prefabs]:GetPosition()
            local next_idx
            local md
            for i = 1, #preview_prefabs do
                local d = p:Dist(preview_prefabs[i]:GetPosition())
                if not md or d < md then
                    next_idx = i
                    md = d
                end
            end
            table.insert(sort_prefabs, preview_prefabs[next_idx])
            table.remove(preview_prefabs, next_idx)
        end
        preview_prefabs = sort_prefabs
        auto_thread = StartThread(function()
            local idx = 1
            local recipe, skin
            while idx <= #preview_prefabs do
                local pos = preview_prefabs[idx] and preview_prefabs[idx]:GetPosition()
                if not pos then
                    break
                end
                if act_type == 'DEPLOY' then
                    MoveActiveItem(prefab)
                    local active_item = ThePlayer.replica.inventory:GetActiveItem()
                    if active_item then
                        local act
                        if GLOBAL.BSPJ.DATA.ROTATE_PLACE then
                            act = BufferedAction(ThePlayer, nil, ACTIONS.DEPLOY, active_item, pos, nil, nil, nil, preview_prefabs[idx].rotation)
                        else
                            act = BufferedAction(ThePlayer, nil, ACTIONS.DEPLOY, active_item, pos)
                        end
                        DoAction(act, true)
                    else
                        break
                    end
                elseif act_type == 'DROP' then
                    MoveActiveItem(prefab)
                    local active_item = ThePlayer.replica.inventory:GetActiveItem()
                    if active_item then
                        local act = BufferedAction(ThePlayer, nil, ACTIONS.DROP, active_item, pos)
                        act.options.wholestack = false
                        DoAction(act, false)
                    else
                        break
                    end
                elseif act_type == 'BUILD' then
                    local controller = ThePlayer.components.playercontroller
                    local builder = ThePlayer.replica.builder

                    if (controller.placer_recipe == nil or controller.placer == nil) and recipe then
                        if not builder:CanBuild(recipe.name) and not builder:IsBuildBuffered(recipe.name) then
                            break
                        end
                        if not builder:IsBuildBuffered(recipe.name) then
                            builder:BufferBuild(recipe.name)
                        end
                        ThePlayer.components.playercontroller:StartBuildPlacementMode(recipe, skin)
                    end
                    if controller.placer_recipe ~= nil and controller.placer ~= nil then
                        recipe = controller.placer_recipe
                        local rotation = controller.placer:GetRotation()
                        if GLOBAL.BSPJ.DATA.ROTATE_PLACE then
                            rotation = preview_prefabs[idx].rotation or rotation
                        end
                        skin = controller.placer_recipe_skin
                        if builder:CanBuildAtPoint(pos, recipe, rotation) then
                            builder:MakeRecipeAtPoint(recipe, pos, rotation, skin)
                        else
                            break
                        end
                    else
                        break
                    end
                end
                preview_prefabs[idx].AnimState:SetAddColour(0.5, 0.5, 0.5, 0)
                Sleep(work_delay)
                repeat
                    Sleep(action_delay)
                until not (ThePlayer.sg and ThePlayer.sg:HasStateTag("moving")) and not ThePlayer:HasTag("moving")
                        and ThePlayer:HasTag("idle") and not ThePlayer.components.playercontroller:IsDoingOrWorking()
                if preview_prefabs[idx] then
                    preview_prefabs[idx]:Hide()
                end
                idx = idx + 1
            end
            kill_auto_thread()
        end, 'bspj_auto_thread')
    else
        SpawnPreviews(prefab, act_type, prefab_inst)
    end
end

------------------------------------------------------------------------------------
local function announce(message, no_whisper)
    local whisper = (GLOBAL.BSPJ.DATA.ANNOUNCE_WHISPER and not oldIsKeyDown(TheInput, KEY_CTRL)) or (not GLOBAL.BSPJ.DATA.ANNOUNCE_WHISPER and oldIsKeyDown(TheInput, KEY_CTRL))
    if no_whisper then
        whisper = false
    end
    TheNet:Say(STRINGS.LMB .. " " .. message, whisper)
end

GLOBAL.BSPJAnnounce = announce

TheInput:AddMouseButtonHandler(function(button, down)
    if TheInput:GetHUDEntityUnderMouse() ~= nil then
        return
    end
    if IsBSPJRecordEnable() then
        if not down and button == MOUSEBUTTON_LEFT then
            ClearSelectionThread()
        end
        if not down then
            return
        end
        if button == MOUSEBUTTON_LEFT then
            if not GLOBAL.IsBSPJRecordHelperReady() then
                GLOBAL.BASE_RECORD_HELPER = SpawnPrefab('base_record_helper')
                GLOBAL.BASE_RECORD_HELPER.Transform:SetPosition(GetOrCapturePos())
                return
            end
            BoxSelect()
            local current_time = GetTime()
            local entity = ConsoleWorldEntityUnderMouse()
            if entity and entity:IsValid() and entity.prefab and entity.Transform and not entity:HasTag("INLIMBO") and entity.AnimState then
                if current_time - last_click.time < double_click_speed and last_click.prefab and last_click.entity == entity then
                    local x, _, z = last_click.pos:Get()
                    for _, ent in pairs(TheSim:FindEntities(x, 0, z, double_click_range, nil, unselectable_tags)) do
                        if ent and ent:IsValid() and ent.prefab and ent.Transform and not ent:HasTag("INLIMBO") and ent.AnimState and ent.prefab == last_click.prefab then
                            GLOBAL.BASE_RECORD_HELPER:SelectTarget(ent)
                        end
                    end
                    last_click.prefab = nil
                    return
                end
                GLOBAL.BASE_RECORD_HELPER:HandleSelection(entity)
                last_click = { prefab = entity.prefab, pos = entity:GetPosition(), time = current_time, entity = entity }
            end
        elseif button == MOUSEBUTTON_RIGHT then
            if GLOBAL.IsBSPJRecordHelperReady() then
                GLOBAL.BASE_RECORD_HELPER:Remove()
                GLOBAL.BASE_RECORD_HELPER = nil
            end
        end
    elseif IsBSPJPlayEnable() then
        if not down then
            return
        end
        if button == MOUSEBUTTON_MIDDLE and IsBuildPlanning() then
            local best_anchor
            local best_d = 1
            local mouse_pos = oldGetWorldPosition(TheInput)
            for anchor in pairs(GLOBAL.BASE_PLAY_HELPER.anchors) do
                local d = mouse_pos:Dist(anchor:GetPosition())
                if d < best_d then
                    best_anchor = anchor
                    best_d = d
                end
            end
            if best_anchor and best_anchor.record_idx and GLOBAL.BSPJ.LAST_RECORD then
                table.remove(GLOBAL.BSPJ.LAST_RECORD.data, best_anchor.record_idx)
                GLOBAL.BASE_PLAY_HELPER:SetRecord(GLOBAL.BSPJ.LAST_RECORD)
                --GLOBAL.BASE_PLAY_HELPER.anchors[best_anchor] = nil
                --best_anchor:Remove()
                return
            end
        end
        if button == MOUSEBUTTON_LEFT and GLOBAL.BSPJ.DATA.QUICK_ANNOUNCE ~= 'off' and oldIsKeyDown(TheInput, KEY_SHIFT) and oldIsKeyDown(TheInput, KEY_ALT) and anchor_pos and last_best_anchor and last_best_anchor.record_item then
            -- [BSPJ] 坐标(%.2f, %.2f, %.2f)需要一个"%s"(%s#%d#%.2f#%s#%s#%s#%.2f#%.2f#%.2f)
            -- x, y, z, name, prefab, layer, rotation, build, anim, bank, scale[1,2,3]
            local x, y, z = last_best_anchor:GetPosition():Get()
            local item = last_best_anchor.record_item
            if GLOBAL.BSPJ.DATA.QUICK_ANNOUNCE == 'on' then
                announce(string.format(STRINGS.BSPJ.QUICK_ANNOUNCE_FORMAT, x, y, z, item.name, item.prefab, item.layer, item.rotation, item.build,
                        tostring(item.anim), tostring(item.bank), item.scale[1], item.scale[2], item.scale[3]))
            else
                local flag = true
                for _, i in ipairs(GLOBAL.BSPJ.ANNOUNCEMENTS) do
                    if i.prefab == item.prefab and i.x == x and i.y == y and i.z == z and i.name == item.name then
                        flag = false
                        break
                    end
                end
                if flag then
                    table.insert(GLOBAL.BSPJ.ANNOUNCEMENTS, 1, {
                        announcer = ThePlayer:GetDisplayName(), x = x, y = y, z = z, name = item.name, prefab = item.prefab,
                        layer = item.layer, build = item.build, anim = item.anim, bank = item.bank,
                        scale = item.scale, rotation = item.rotation
                    })
                    ThePlayer.components.talker:Say(STRINGS.BSPJ.MESSAGE_CAPTURED)
                end
            end
            return
        end
        if GLOBAL.IsBSPJPlayHelperReady() and oldIsKeyDown(TheInput, GLOBAL['KEY_' .. BSPJ.DATA.AUTO_WORK]) then
            local LMBAction, RMBAction = ThePlayer.components.playeractionpicker:DoGetMouseActions()
            if button == MOUSEBUTTON_RIGHT then
                if RMBAction and RMBAction.action == ACTIONS.DEPLOY and RMBAction.invobject and RMBAction.invobject.prefab then
                    SpawnPreviewsOrAutoWork(RMBAction.invobject.prefab, 'DEPLOY')
                    return
                end
            elseif button == MOUSEBUTTON_LEFT then
                if LMBAction and LMBAction.action == ACTIONS.DROP and LMBAction.invobject and LMBAction.invobject.prefab then
                    SpawnPreviewsOrAutoWork(LMBAction.invobject.prefab, 'DROP', LMBAction.invobject)
                    return
                end
                local controller = ThePlayer.components.playercontroller
                if controller.placer_recipe ~= nil and controller.placer ~= nil and controller.placer_recipe.name then
                    SpawnPreviewsOrAutoWork(controller.placer_recipe.name, 'BUILD')
                    return
                end
            end
            return
        end
        if button == MOUSEBUTTON_LEFT then
            if not GLOBAL.IsBSPJPlayHelperReady() then
                GLOBAL.BASE_PLAY_HELPER = SpawnPrefab('base_play_helper')
                GLOBAL.BASE_PLAY_HELPER:UpdatePos(GetOrCapturePos())
            end
        end
    end
end)

local function OnCenterUpdate()
    local cc = GetOrCreateCenter()
    if (GLOBAL.IsBSPJRecordHelperReady() or not IsBSPJRecordEnable()) and (GLOBAL.IsBSPJPlayHelperReady() or not IsBSPJPlayEnable()) then
        cc:Hide()
        cc.grid:Hide()
        return
    end
    cc:Show()
    cc.grid:Show()
    local x, y, z = GetOrCapturePos()
    cc.Transform:SetPosition(x, y, z)
    cc.grid.Transform:SetPosition(GLOBAL.BSPJGetTurfCenter(x, y, z))
end

local function OnUpdateAnchorPos()
    if not IsBSPJPlayEnable() or not GLOBAL.IsBSPJPlayHelperReady() then
            anchor_pos = nil
            if last_best_anchor and last_best_anchor:IsValid() then
                -- last_best_anchor.AnimState:SetAddColour(last_best_anchor.spacing_color or 0, 0, 0, 0)
                last_best_anchor.AnimState:SetAddColour(0, 0, 0, 0)
            end
            last_best_anchor = nil
            return
        end
    local best_anchor
    local best_d = 1
    local mouse_pos = oldGetWorldPosition(TheInput)
    for anchor in pairs(GLOBAL.BASE_PLAY_HELPER.anchors) do
        local d = mouse_pos:Dist(anchor:GetPosition())
        if d < best_d then
            best_anchor = anchor
            best_d = d
        end
    end

    --local candidates = TheSim:FindEntities(mouse_pos.x, 0, mouse_pos.z, best_d, { 'BSPJAnchor' }, { })
    --for _, anchor in pairs(candidates) do
    --    local d = mouse_pos:Dist(anchor:GetPosition())
    --    if d < best_d then
    --        best_anchor = anchor
    --        best_d = d
    --    end
    --end

    if last_best_anchor ~= best_anchor and last_best_anchor and last_best_anchor:IsValid() then
            -- last_best_anchor.AnimState:SetAddColour(last_best_anchor.spacing_color or 0, 0, 0, 0)
            last_best_anchor.AnimState:SetAddColour(0, 0, 0, 0)
        end
    if best_anchor ~= nil and best_anchor:IsValid() then
        anchor_pos = best_anchor:GetPosition()
        if best_anchor ~= last_best_anchor then
            best_anchor.AnimState:SetAddColour(0.5, 0.5, 0.5, 0)
        end
    else
        anchor_pos = nil
    end
    last_best_anchor = best_anchor
    if IsBuildPlanning() then
        anchor_pos = nil
    end
end

local interrupt_controls = {}
for control = CONTROL_ATTACK, CONTROL_MOVE_RIGHT do
    interrupt_controls[control] = true
end
local mouse_controls = { [CONTROL_PRIMARY] = false, [CONTROL_SECONDARY] = true }
AddComponentPostInit('playercontroller', function(PlayerController, inst)
    if inst ~= ThePlayer then
        return
    end

    local oldOnControl = PlayerController.OnControl
    PlayerController.OnControl = function(self, control, down)
        if IsBSPJRecordEnable() or (IsBSPJPlayEnable() and (not GLOBAL.IsBSPJPlayHelperReady() or (oldIsKeyDown(TheInput, GLOBAL['KEY_' .. BSPJ.DATA.AUTO_WORK]) and anchor_pos ~= nil))) then
            if control == CONTROL_PRIMARY or control == CONTROL_SECONDARY then
                return
            end
        end
        local mouse_control = mouse_controls[control]
        if down and auto_thread and IsDefaultScreen() and (interrupt_controls[control] or mouse_control ~= nil and not TheInput:GetHUDEntityUnderMouse()) then
            kill_auto_thread()
        end
        return oldOnControl(self, control, down)
    end

    local oldOnUpdate = PlayerController.OnUpdate
    PlayerController.OnUpdate = function(self, ...)
        OnCenterUpdate()
        OnUpdateAnchorPos()
        return oldOnUpdate(self, ...)
    end

    local oldDoAction = PlayerController.DoAction
    PlayerController.DoAction = function(self, buffaction, ...)
        if buffaction and buffaction.action and buffaction.pos and IsBuildPlanning() and self.ismastersim then
            if buffaction.action == ACTIONS.DROP or buffaction.action == ACTIONS.DEPLOY then
                local pos = buffaction:GetActionPoint()
                PlanningAtPos(buffaction.action == ACTIONS.DROP and 'drop' or 'deploy', pos.x, pos.z)
                return
            end
        end
        return oldDoAction(self, buffaction, ...)
    end
end)

------------------------------------------------------------------------------------

AddComponentPostInit("highlight", function(Highlight, inst)
    local oldHighlight = Highlight.Highlight
    Highlight.Highlight = function(self, ...)
        if GLOBAL.IsBSPJRecordHelperReady() and GLOBAL.BASE_RECORD_HELPER.anchors[inst] then
            return
        end
        oldHighlight(self, ...)
    end
    local oldUnHighlight = Highlight.UnHighlight
    Highlight.UnHighlight = function(self)
        if GLOBAL.IsBSPJRecordHelperReady() and GLOBAL.BASE_RECORD_HELPER.anchors[inst] then
            return
        end
        oldUnHighlight(self)
    end
end)

------------------------------------------------------------------------------------

-- 捕获聊天信息中的坐标
local oldNetworking_Say = GLOBAL.Networking_Say
GLOBAL.Networking_Say = function(guid, userid, name, prefab, message, ...)
    if GLOBAL.BSPJ.DATA.CAPTURE_ANNOUNCE and message and ThePlayer and (GLOBAL.BSPJ.DATA.CAPTURE_SELF or userid ~= ThePlayer.userid) then
        -- '[BSPJ] 坐标(%.2f, %.2f, %.2f)需要一个"%s" | (%s#%d#%.2f#%s#%s#%s#%.2f#%.2f#%.2f)'
        local _, _, x, y, z, n, p, layer, rotation, build, anim, bank, s1, s2, s3 = string.find(
                message, '%[BSPJ][^(]-%(([^,]*),%s*([^,]*),%s*([^)]*)%)[^"]-"(.*)" | %(([^#]*)#([^#]*)#([^#]*)#([^#]*)#([^#]*)#([^#]*)#([^#]*)#([^#]*)#([^#]*)%)')
        if x and y and z and n and p and layer and rotation and build and s1 and s2 and s3 then
            x, y, z, layer, rotation, s1, s2, s3 = tonumber(x), tonumber(y), tonumber(z), tonumber(layer), tonumber(rotation), tonumber(s1), tonumber(s2), tonumber(s3)
            if anim == 'nil' then
                anim = nil
            end
            if bank == 'nil' then
                bank = nil
            end
            local flag = true
            for _, item in ipairs(GLOBAL.BSPJ.ANNOUNCEMENTS) do
                if item.prefab == p and item.x == x and item.y == y and item.z == z and item.name == n then
                    flag = false
                    break
                end
            end
            if flag then
                table.insert(GLOBAL.BSPJ.ANNOUNCEMENTS, 1, {
                    announcer = name, x = x, y = y, z = z, name = n, prefab = p,
                    layer = layer, build = build, anim = anim, bank = bank,
                    scale = { s1, s2, s3 }, rotation = rotation
                })
                ThePlayer.components.talker:Say(STRINGS.BSPJ.MESSAGE_CAPTURED)
            end
        end
    end
    return oldNetworking_Say(guid, userid, name, prefab, message, ...)
end

------------------------------------------------------------------------------------

