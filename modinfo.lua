name = "Base Projection (基地投影)"
description = [[
在游戏中按F1开始基地录入，录入时通过鼠标左键选定基地中心后，左键单击可以添加或删除实体，双击添加同类实体，按住拖拽添加一个区域内的实体
选完实体后，点击面板中的“保存”按钮即可保存数据
按F2开始基地投影，选定中心后，点击面板中的“打开列表”按钮，选择要投影的数据即可
摆放时鼠标会自动吸附到投影点上，可以轻松的复原基地
理论上兼容所有模组
]]
author = "NoMu，冰冰羊，THEDOG"
version = "2.0.7"

folder_name = folder_name or "base_projection"
if not folder_name:find("workshop-") then
    name = name.." -dev"
end

dst_compatible = true
client_only_mod = true
all_clients_require_mod = false

icon_atlas = "modicon.xml"
icon = "modicon.tex"

api_version = 10

priority = -1000000

local key_list = { "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12", "TAB", "CAPSLOCK", "LSHIFT", "RSHIFT", "LCTRL", "RCTRL", "LALT", "RALT", "ALT", "CTRL", "SHIFT", "SPACE", "ENTER", "ESCAPE", "MINUS", "EQUALS", "BACKSPACE", "PERIOD", "SLASH", "LEFTBRACKET", "BACKSLASH", "RIGHTBRACKET", "TILDE", "PRINT", "SCROLLOCK", "PAUSE", "INSERT", "HOME", "DELETE", "END", "PAGEUP", "PAGEDOWN", "UP", "DOWN", "LEFT", "RIGHT", "KP_DIVIDE", "KP_MULTIPLY", "KP_PLUS", "KP_MINUS", "KP_ENTER", "KP_PERIOD", "KP_EQUALS" }
local key_options = {}

for i = 1, #key_list do
    key_options[i] = { description = key_list[i], data = "KEY_" .. key_list[i] }
end

key_options[#key_list + 1] = {
    description = '-', data = 'KEY_MINUS'
}

configuration_options = {
    {
        name = "language",
        label = "选择语言（Select language）",
        options = {
            { description = '中文', data = "zh" },
            { description = 'English', data = "en" },
        },
        default = "zh",
    },
{
    name = "projection_version",
    label = "投影算法版本 (Projection Version)",
    hover = "新版效果更好，老版稳定报错了换老版/If the mod reports an error, please switch to the older version.",
    options = {
        { description = "新版/new", data = "new" },
        { description = "老版/older", data = "old" },
    },
    default = "new",
},
    {
        name = "key_toggle_record",
        label = "基地录入快捷键（Base Record Shortcut）",
        options = key_options,
        default = "KEY_F1",
        is_keybind = true, -- 兼容配置扩展模组
    },
    {
        name = "key_toggle_play",
        label = "基地预览快捷键（Base Preview Shortcut）",
        options = key_options,
        default = "KEY_F2",
        is_keybind = true, -- 兼容配置扩展模组
    }
}
