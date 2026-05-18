local SPACING_DICT = require("utils/spacing")
local valid_prefab = {}
local unknown_anim_prefabs = { mighty_gym = true, singingshell_octave3 = true, singingshell_octave4 = true, singingshell_octave5 = true }

local function anchor_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:SetCanSleep(false)
    inst.persists = false

    if not BSPJ.is_build_planing then
        inst:AddTag("CLASSIFIED")
        inst:AddTag("NOCLICK")
    end
    inst:AddTag("placer")
    inst:AddTag("BSPJAnchor")

    inst.displaynamefn = function()
        local prefab = inst.record_item and inst.record_item.prefab
        if prefab then
            return (STRINGS.NAMES[prefab:upper()] or prefab) .. STRINGS.BSPJ.NAME_ANCHOR
        else
            return STRINGS.BSPJ.NAME_ANCHOR
        end
    end

    inst.AnimState:SetBuild("unknown_prefab")
    inst.AnimState:SetBank("unknown_prefab")
    inst.AnimState:PlayAnimation('idle')

    --inst.AnimState:SetBank("boat_01")
    --inst.AnimState:SetBuild("boat_test")
    --inst.AnimState:PlayAnimation("idle_full")

    inst.AnimState:SetMultColour(0, 1, 0, 0.8)
    --inst.Transform:SetScale(0.35, 0.35, 0.35)

    local label = inst.entity:AddLabel()

    label:SetFontSize(18)
    label:SetFont(BODYTEXTFONT)
    label:SetWorldOffset(0, 1.5, 0)

    label:SetColour(1, 1, 0)
    label:Enable(false)
    inst.label = label
    inst.is_anim_valid = false

    function inst:SetPreview(item)
        self.record_item = item
        local build = item.build
        if build and item.bank and item.anim and Prefabs and Prefabs[item.prefab] then
            self.AnimState:SetBuild(build)
            if self.AnimState:GetBuild() ~= build then
                local dump = SpawnPrefab(item.prefab)
                if dump and dump:IsValid() and dump.AnimState then
                    build = dump.AnimState:GetBuild()
                    if build then
                        self.AnimState:SetBuild(build)
                    end
                    dump:Remove()
                end
            end
            if self.AnimState:GetBuild() == build then
                self.AnimState:SetBank(item.bank)
                self.AnimState:PlayAnimation(item.anim)
                if unknown_anim_prefabs[self.record_item.prefab] then
                    self:SetAnim(false)
                else
                    self:SetAnim(true)
                end
                if not BSPJ.DATA.SHOW_NAME then
                    return
                end
            else
                self.AnimState:SetBuild("unknown_prefab")
            end
        end
        self.label:Enable(true)
        self.label:SetText(item.name)
        self.record_name = item.name
    end

    function inst:SetAnim(valid)
        self.is_anim_valid = true
        local item = self.record_item
        if valid then
            local scale = item.scale or { 1, 1, 1 }
            self.Transform:SetScale(scale[1], scale[2], scale[3])
            if item.rotation and item.rotation ~= 0 then
                if math.fmod(item.rotation, 60) == 0 then
                    self.Transform:SetSixFaced()
                else
                    self.Transform:SetEightFaced()
                end
                self.Transform:SetRotation(item.rotation or 0)
            end
            if item.layer and item.layer ~= 6 then
                self.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
                self.AnimState:SetLayer(item.layer)
                self.AnimState:SetSortOrder(5)
            end
        else
            self.AnimState:SetBuild("unknown_prefab")
            self.AnimState:SetBank("unknown_prefab")
            self.AnimState:PlayAnimation('idle')
            self.label:Enable(true)
            self.record_name = item.name
            if BSPJ.DATA.ORDER_TIPS and self.record_spacing then
                self.label:SetText(item.name .. '\n' .. tostring(self.record_spacing))
            else
                self.label:SetText(item.name)
            end
        end
    end

    function inst:_valid(dx, dy, dz, try_time)
        local item = self.record_item
        if try_time > 100 then
            for k in pairs(valid_prefab[item.prefab]) do
                k:SetAnim(false)
            end
            valid_prefab[item.prefab] = nil
            return
        end
        local w, h = TheSim:GetScreenSize()
        local sx = math.random() * w
        local sy = math.random() * h
        local x, y, z = TheSim:ProjectScreenPos(sx, sy)
        local dump = SpawnPrefab('base_anchor')
        dump.AnimState:SetMultColour(0, 0, 0, 0)
        dump.Transform:SetPosition(x, y, z)
        self:DoTaskInTime(0, function()
            local dump_entities = TheSim:GetEntitiesAtScreenPoint(TheSim:GetScreenPos(x, y, z))
            local valid_pos = false
            for _, entity in ipairs(dump_entities) do
                if entity == dump then
                    valid_pos = true
                    break
                end
            end
            dump:Remove()
            if valid_pos then
                self.Transform:SetPosition(x, y, z)
                self:DoTaskInTime(0, function()
                    local entities = TheSim:GetEntitiesAtScreenPoint(TheSim:GetScreenPos(x, y, z))
                    local valid_anim = false
                    for _, entity in ipairs(entities) do
                        if entity == self then
                            valid_anim = true
                            break
                        end
                    end
                    for k in pairs(valid_prefab[item.prefab]) do
                        k:SetAnim(valid_anim)
                    end
                    valid_prefab[item.prefab] = valid_anim
                    self.Transform:SetPosition(dx, dy, dz)
                end)
            else
                self:_valid(dx, dy, dz, try_time + 1)
            end
        end)
    end

    function inst:ValidAnim(dx, dy, dz)
        if self.is_anim_valid then
            return
        end
        local item = self.record_item
        if type(valid_prefab[item.prefab]) == 'boolean' then
            self:SetAnim(valid_prefab[item.prefab])
            return
        elseif type(valid_prefab[item.prefab]) == 'table' then
            valid_prefab[item.prefab][self] = true
            return
        end
        valid_prefab[item.prefab] = { [self] = true }
        self:_valid(dx, dy, dz, 0)
    end

    function inst:UpdatePos(x, y, z)
        self.Transform:SetPosition(x, y, z)
        --if BSPJ.DATA.ANIM_VALID then
        --    self:ValidAnim(x, y, z)
        --else
        --    if unknown_anim_prefabs[self.record_item.prefab] then
        --        self:SetAnim(false)
        --    else
        --        self:SetAnim(true)
        --    end
        --end
    end

    return inst
end

local function center_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst:AddTag("CLASSIFIED")
    inst:AddTag("NOCLICK")
    inst:AddTag("placer")

    inst.AnimState:SetBank("boat_01")
    inst.AnimState:SetBuild("boat_test")
    inst.AnimState:PlayAnimation("idle_full")

    inst.AnimState:SetLightOverride(1)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    inst.AnimState:SetSortOrder(5)
    inst.AnimState:SetAddColour(1, 1, 0, 0)
    local outer_scale = 0.35
    inst.Transform:SetScale(outer_scale, outer_scale, outer_scale)

    inst.grid = SpawnPrefab('gridplacer')
    inst.grid.AnimState:SetAddColour(1, 1, 0, 0)
    inst.grid.AnimState:SetSortOrder(5)
    inst:ListenForEvent("onremove", function(_inst)
        _inst.grid:Remove()
    end)

    local label = inst.entity:AddLabel()

    label:SetFontSize(18)
    label:SetFont(BODYTEXTFONT)
    label:SetWorldOffset(0, 0.8, 0)

    label:SetText(STRINGS.BSPJ.LABEL_PLEASE_SELECT)
    label:SetColour(1, 1, 0)
    label:Enable(true)
    inst.label = label

    return inst
end

local function record_helper_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst:AddTag("CLASSIFIED")
    inst:AddTag("NOCLICK")
    inst:AddTag("placer")

    inst.AnimState:SetBank("boat_01")
    inst.AnimState:SetBuild("boat_test")
    inst.AnimState:PlayAnimation("idle_full")

    inst.AnimState:SetLightOverride(1)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)
    inst.AnimState:SetSortOrder(6)
    inst.AnimState:SetAddColour(1, 1, 0, 0)
    local outer_scale = 0.30
    inst.Transform:SetScale(outer_scale, outer_scale, outer_scale)

    local label = inst.entity:AddLabel()

    label:SetFontSize(18)
    label:SetFont(BODYTEXTFONT)
    label:SetWorldOffset(0, 0.8, 0)

    label:SetText(STRINGS.BSPJ.LABEL_BASE_CENTER)
    label:SetColour(1, 1, 0)
    label:Enable(true)
    inst.label = label

    inst.color = { x = 0, y = 1, z = 0 }
    inst.anchors = {}
    function inst:SelectTarget(target)
        if self.anchors[target] then
            return
        end
        self.anchors[target] = true

        if not target.components.highlight then
            target:AddComponent("highlight")
        end
        local highlight = target.components.highlight
        highlight.highlight_add_colour_red = nil
        highlight.highlight_add_colour_green = nil
        highlight.highlight_add_colour_blue = nil
        highlight:SetAddColour(self.color)
        highlight.highlit = true
    end

    function inst:DeselectTarget(target)
        if self.anchors[target] then
            self.anchors[target] = nil
            if target:IsValid() and target.components.highlight then
                target.components.highlight:UnHighlight()
            end
        end
    end

    function inst:HandleSelection(target)
        if self.anchors[target] then
            self:DeselectTarget(target)
        else
            self:SelectTarget(target)
        end
    end

    function inst:GetBaseData()
        local record = {}
        for anchor in pairs(self.anchors) do
            if anchor:IsValid() then
                local x, y, z = anchor:GetPosition():Get()
                local build = anchor.AnimState:GetBuild()
                local bank = anchor.AnimState:GetCurrentBankName()
                local _, anim = anchor.AnimState:GetHistoryData()
                local sx, sy, sz = anchor.Transform:GetScale()
                local rotation = anchor.Transform:GetFacingRotation()
                local layer = anchor.AnimState:GetLayer()
                table.insert(record, {
                    name = anchor:GetDisplayName(), prefab = anchor.prefab, x = x, y = y, z = z,
                    build = build, bank = bank, anim = anim, scale = { sx, sy, sz },
                    rotation = rotation, layer = layer
                })
            end
        end
        return record
    end

    inst:ListenForEvent("onremove", function(_inst)
        for anchor in pairs(_inst.anchors) do
            _inst:DeselectTarget(anchor)
        end
    end)

    return inst
end

local function play_helper_fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:SetCanSleep(false)
    inst.persists = false

    inst:AddTag("CLASSIFIED")
    inst:AddTag("NOCLICK")
    inst:AddTag("placer")

    inst.AnimState:SetBank("boat_01")
    inst.AnimState:SetBuild("boat_test")
    inst.AnimState:PlayAnimation("idle_full")

    inst.AnimState:SetLightOverride(1)
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    inst.AnimState:SetLayer(LAYER_WORLD_BACKGROUND)
    inst.AnimState:SetSortOrder(6)
    inst.AnimState:SetAddColour(1, 1, 0, 0)
    local outer_scale = 0.30
    inst.Transform:SetScale(outer_scale, outer_scale, outer_scale)

    local label = inst.entity:AddLabel()

    label:SetFontSize(18)
    label:SetFont(BODYTEXTFONT)
    label:SetWorldOffset(0, 0.8, 0)

    label:SetText(STRINGS.BSPJ.LABEL_BASE_CENTER)
    label:SetColour(1, 1, 0)
    label:Enable(true)
    inst.label = label

    inst.anchors = {}
    function inst:SetRecord(record)
        for anchor in pairs(self.anchors) do
            if anchor:IsValid() then
                anchor:Remove()
            end
        end
        self.anchors = {}
        local bx, bz = record.x, record.z
        local max_spacing, min_spacing
        for idx, item in ipairs(record.data) do
            local anchor = SpawnPrefab('base_anchor')
            anchor:SetPreview(item)
            anchor.record_prefab = item.prefab
            anchor.record_idx = idx
            local spacing = SPACING_DICT[item.prefab]
            if not spacing then
                if AllRecipes and AllRecipes[item.prefab] and AllRecipes[item.prefab].min_spacing then
                    local dump = SpawnPrefab(item.prefab)
                    if dump:HasTag('structure') then
                        spacing = AllRecipes[item.prefab].min_spacing
                    end
                    if dump and dump:IsValid() then
                        dump:Remove()
                    end
                    --else
                    --    local dump = SpawnPrefab('dug_' .. item.prefab)
                    --    if dump and dump.replica and dump.replica.inventoryitem then
                    --        spacing = dump.replica.inventoryitem:DeploySpacingRadius()
                    --    end
                    --    if dump and dump:IsValid() then
                    --        dump:Remove()
                    --    end
                end
            end
            if spacing then
                if not max_spacing or spacing > max_spacing then
                    max_spacing = spacing
                end
                if not min_spacing or spacing < min_spacing then
                    min_spacing = spacing
                end
                anchor.record_spacing = spacing
            end
            self.anchors[anchor] = { dx = item.x - bx, dz = item.z - bz }
        end
        if BSPJ.DATA.ORDER_TIPS then
            for anchor in pairs(self.anchors) do
                if anchor.record_spacing then
                    anchor.spacing_color = (anchor.record_spacing - min_spacing) / (max_spacing - min_spacing) * 0.9 + 0.1
                    anchor.AnimState:SetAddColour(anchor.spacing_color, 0, 0, 0)
                    anchor.label:Enable(true)
                    if anchor.record_name then
                        anchor.label:SetText(anchor.record_name .. '\n' .. tostring(anchor.record_spacing))
                    else
                        anchor.label:SetText(tostring(anchor.record_spacing))
                    end
                end
            end
        end
        BSPJ.LAST_RECORD = json.decode(json.encode(record))
        BSPJ.SaveLast()
        self:UpdatePos(self:GetPosition():Get())
    end

    function inst:UpdatePos(x, y, z)
        BSPJ.LAST_POS = { x, y, z }
        BSPJ.SaveLast()
        self.Transform:SetPosition(x, y, z)
        for anchor, pos in pairs(self.anchors) do
            local dx, dz = BSPJRotate(pos.dx, pos.dz, BSPJ.DATA.ANGLE)
            anchor:UpdatePos(x + dx, 0, z + dz)
        end
    end
    inst:ListenForEvent("onremove", function(_inst)
        for anchor in pairs(_inst.anchors) do
            if anchor:IsValid() then
                anchor:Remove()
            end
        end
    end)

    return inst
end

return Prefab('base_anchor', anchor_fn), Prefab('base_center', center_fn), Prefab('base_record_helper', record_helper_fn), Prefab('base_play_helper', play_helper_fn)
