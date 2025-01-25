--@amzxyz https://github.com/amzxyz/rime_zrm
--由于comment_format不管你的表达式怎么写，只能获得一类输出，导致的结果只能用于一个功能类别
--如果依赖lua_filter载入多个lua也只能实现一些单一的、不依赖原始注释的功能，有的时候不可避免的发生一些逻辑冲突
--所以此脚本专门为了协调各式需求，逻辑优化，实现参数自定义，功能可开关，相关的配置跟着方案文件走，如下所示：
--将如下相关位置完全暴露出来，注释掉其它相关参数--
--  comment_format: {comment}   #将注释以词典字符串形式完全暴露，通过pro_comment_format.lua完全接管。
--  spelling_hints: 10          # 将注释以词典字符串形式完全暴露，通过pro_comment_format.lua完全接管。
--在方案文件顶层置入如下设置--
--#Lua 配置: 超级注释模块
--pro_comment_format:                     # 超级注释，子项配置 true 开启，false 关闭
--  corrector: true                       # 启用错音错词提醒，例如输入 geiyu 给予 获得 jǐ yǔ 提示
--  corrector_type: "{comment}"           # 新增一个提示类型，比如"【{comment}】" 
--  candidate_length: 1                   # 候选词辅助码提醒的生效长度，0为关闭，但建议使用开关或者快捷键实现      


-- #########################
-- # 错音错字提示模块 (Corrector)
-- #########################
local CR = {}
local corrections_cache = nil  -- 用于缓存已加载的词典

-- 加载纠正词典函数
local function load_corrections(file_path)
    if corrections_cache then return corrections_cache end

    local corrections = {}
    local file = io.open(file_path, "r")

    if file then
        for line in file:lines() do
            if not line:match("^#") then
                -- 使用制表符分隔字段
                local text, code, weight, comment = line:match("^(.-)\t(.-)\t(.-)\t(.-)$")
                if text and code then
                    -- 去除首尾空格
                    text = text:match("^%s*(.-)%s*$")
                    code = code:match("^%s*(.-)%s*$")
                    comment = comment and comment:match("^%s*(.-)%s*$") or ""

                    -- 存储到 corrections 表中，以 code 为键
                    corrections[code] = { text = text, comment = comment }
                end
            end
        end
        file:close()
        corrections_cache = corrections
    end
    return corrections
end
function CR.init(env)
    local config = env.engine.schema.config

    -- 初始化 corrector_type 和样式
    env.settings.corrector_type = (env.settings.corrector_type and env.settings.corrector_type:gsub('^*', '')) or '{comment}'
    CR.style = config:get_string("pro_comment_format/corrector_type") or '{comment}'

    -- 仅在 corrections_cache 为 nil 时加载词典
    if not corrections_cache then
        local corrections_file_path = rime_api.get_user_data_dir() .. "/cn_dicts/corrections.dict.yaml"
        CR.corrections = load_corrections(corrections_file_path)
    end
end

function CR.run(cand, env)
    -- 使用候选词的 comment 作为 code，在缓存中查找对应的修正
    local correction = corrections_cache[cand.comment]
    if correction and cand.text == correction.text then
        -- 用新的注释替换默认注释
        local final_comment = CR.style:gsub("{comment}", correction.comment)
        return final_comment
    end

    return nil
end
-- #########################
-- # 拼音提示模块 (PinyinHint)
-- #########################

local PY = {}

function PY.run(cand, env, initial_comment)
    local length = utf8.len(cand.text)
    local final_comment = nil
    -- 确保候选词长度检查使用从配置中读取的值
    if env.settings.pinyinhint_enabled and length <= env.settings.candidate_length then
        -- 直接将注释显示为最终注释
        final_comment = initial_comment
    else
        -- 如果候选词长度超过指定值，返回空字符串
        final_comment = ""
    end

    return final_comment or ""  -- 确保返回最终值
end

-- ################################
-- 部件组字返回的注释（radical_pinyin）
-- ################################
local AZ = {}
-- 处理函数，只负责处理候选词的注释
function AZ.run(cand, env, initial_comment)
    local final_comment

    -- 如果注释不为空，添加括号
    if initial_comment and initial_comment ~= "" then
        final_comment = string.format("〔 %s 〕", initial_comment)
    end

    return final_comment  -- 返回最终注释
end
-- #########################
-- 主函数：根据优先级处理候选词的注释
-- #########################
-- 主函数：根据优先级处理候选词的注释
local ZH = {}
function ZH.init(env)
    local config = env.engine.schema.config

    -- 检查开关状态
    local is_pinyinhint_enabled = env.engine.context:get_option("pinyinhint")

    -- 设置辅助码功能
    env.settings = {
        corrector_enabled = config:get_bool("pro_comment_format/corrector") or true,  -- 错音错词提醒功能
        corrector_type = config:get_string("pro_comment_format/corrector_type") or "{comment}",  -- 提示类型
        pinyinhint_enabled = is_pinyinhint_enabled,  -- 读音显示功能通过开关控制
        candidate_length = tonumber(config:get_string("pro_comment_format/candidate_length")) or 1,  -- 候选词长度
    }
end

function ZH.func(input, env)
    -- 初始化
    ZH.init(env)
    CR.init(env)

    --声明反查模式的tag状态
	local seg = env.engine.context.composition:back()
	env.is_radical_mode = seg and (
		seg:has_tag("radical_lookup") 
		or seg:has_tag("reverse_stroke") 
		or seg:has_tag("add_user_dict")
	) or false


    -- 遍历输入的候选词
    for cand in input:iter() do
        local initial_comment = cand.comment
        local final_comment = initial_comment

        -- 处理辅助码提示
        if env.settings.pinyinhint_enabled then
            local py_comment = PY.run(cand, env, initial_comment)
            if py_comment then
                final_comment = py_comment
            end
        else
            -- 如果辅助码显示被关闭，则清空注释
            final_comment = ""

        end

        -- 处理错音错词提示
        if env.settings.corrector_enabled then
            local cr_comment = CR.run(cand, env, initial_comment)
            if cr_comment then
                final_comment = cr_comment
            end
        end

        -- 处理部件组字模式注释
        if env.is_radical_mode then
            local az_comment = AZ.run(cand, env, initial_comment)
            if az_comment then
                final_comment = az_comment
            end
        end

        -- 更新最终注释
        if final_comment ~= initial_comment then
            cand:get_genuine().comment = final_comment
        end

        yield(cand)  -- 输出当前候选词
    end
end
return {
    CR = CR,
    PY = PY,
    AZ = AZ,
    ZH = ZH,
    func = ZH.func
}