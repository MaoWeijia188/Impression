-- =====================================================================
--  印象问答 Impression · V2 种子数据（当前 v2.0 题库）
-- ---------------------------------------------------------------------
--  依赖: 先执行 V1__init_schema.sql
--  内容: 1 份示例问卷 + 11 道题 + 预设选项
--  可重复执行: 否。重复执行会插入第 2 份问卷（share_code 唯一索引会拦下问卷，
--              但重复执行本身没有意义）。要重来请先重跑 V1。
--
--  题库来源: docs/06-题库设计.md v2.0
--            docs/../prototype/index.html 顶部的 QUESTIONS 数组（前端同源）
--
--  ⚠️ 执行前请先改掉下面两个占位值（见文件末尾说明）
-- =====================================================================

USE impression;

-- 显式声明客户端字符集，避免中文题干 / 选项存成乱码
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;

-- ---------------------------------------------------------------------
-- 你的身份凭证。管理接口（改标题、关问卷、看统计）都要带它。
-- 现在这个是随机生成的，可以直接用；也可以换成你自己生成的值。
-- ★ 请把它抄到一个安全的地方，丢了就找不回这份问卷了。
-- ---------------------------------------------------------------------
SET @owner_token = 'T5CZNktXHiZxjLTqFYQjUQPs2Dec9qlLGoXDefSP1xY';  -- 43 位

-- 分享码：答题链接 /u/{share_code} 用。必须不可预测，所以用随机值。
SET @share_code  = 'NHnPAlu5C2w';                                  -- 11 位


-- =====================================================================
-- 1. 一份示例问卷
-- =====================================================================
INSERT INTO questionnaire (owner_token, title, description, share_code, status)
VALUES (@owner_token,
        '维嘉的印象问答',
        '花 1 分钟，告诉我你眼中的我是什么样的人',
        @share_code,
        1);

SET @qid = LAST_INSERT_ID();


-- =====================================================================
-- 2. 11 道题
--
--    字段约定（v2.0 题型统一后）：
--      dimension   所属维度，结果页按它分组
--      type        1=有预设选项  2=纯自由填写
--      required    恒为 0（全部可跳过）
--      max_choices 0=不限；想限制就改成 3 之类
--      max_length  自定义答案字数上限，统一 200
-- =====================================================================


-- ---------- 维度一：第一印象 ----------
INSERT INTO question (questionnaire_id, dimension, type, title, required, max_choices, max_length, sort_order)
VALUES (@qid, '第一印象', 1, '第一次接触我时，我在你眼里有哪些标签？', 0, 0, 200, 1);
SET @q1 = LAST_INSERT_ID();
INSERT INTO question_option (question_id, content, sort_order) VALUES
  (@q1, '靠谱',           1),
  (@q1, '高冷',           2),
  (@q1, '话少',           3),
  (@q1, '幽默',           4),
  (@q1, '认真',           5),
  (@q1, '面善',           6),
  (@q1, '有点神秘',       7),
  (@q1, '平易近人',       8),
  (@q1, '不太有印象',     9);

INSERT INTO question (questionnaire_id, dimension, type, title, required, max_choices, max_length, sort_order)
VALUES (@qid, '第一印象', 2, '第一次接触我时，你对我最深的印象是什么？', 0, 0, 200, 2);
SET @q2 = LAST_INSERT_ID();


-- ---------- 维度二：相处体验 ----------
INSERT INTO question (questionnaire_id, dimension, type, title, required, max_choices, max_length, sort_order)
VALUES (@qid, '相处体验', 1, '相处中，我的哪些表现让你觉得舒服？', 0, 0, 200, 3);
SET @q3 = LAST_INSERT_ID();
INSERT INTO question_option (question_id, content, sort_order) VALUES
  (@q3, '会记得你说过的小事',   1),
  (@q3, '不太打断你说话',       2),
  (@q3, '有事能帮就帮',         3),
  (@q3, '不会把话说得太绝',     4),
  (@q3, '情绪比较稳定',         5),
  (@q3, '说不出来',             6);

INSERT INTO question (questionnaire_id, dimension, type, title, required, max_choices, max_length, sort_order)
VALUES (@qid, '相处体验', 2, '和我相处下来，你最真实的感受是什么？有没有哪个瞬间让你印象特别深？', 0, 0, 200, 4);
SET @q4 = LAST_INSERT_ID();


-- ---------- 维度三：性格特征 ----------
INSERT INTO question (questionnaire_id, dimension, type, title, required, max_choices, max_length, sort_order)
VALUES (@qid, '性格特征', 1, '你觉得我最突出的优点是？', 0, 0, 200, 5);
SET @q5 = LAST_INSERT_ID();
INSERT INTO question_option (question_id, content, sort_order) VALUES
  (@q5, '真诚、不装',           1),
  (@q5, '靠谱、说到做到',       2),
  (@q5, '聪明、学东西快',       3),
  (@q5, '幽默、会活跃气氛',     4),
  (@q5, '细心、会照顾人情绪',   5),
  (@q5, '有主见、能扛事',       6);

INSERT INTO question (questionnaire_id, dimension, type, title, required, max_choices, max_length, sort_order)
VALUES (@qid, '性格特征', 1, '如果一定要说一个我最需要改的地方，你会选？', 0, 0, 200, 6);
SET @q6 = LAST_INSERT_ID();
INSERT INTO question_option (question_id, content, sort_order) VALUES
  (@q6, '太在意别人的看法',       1),
  (@q6, '有点拖延、三分钟热度',   2),
  (@q6, '想太多、容易内耗',       3),
  (@q6, '表达不够直接',           4),
  (@q6, '太爱较真',               5),
  (@q6, '没什么要改的',           6);

INSERT INTO question (questionnaire_id, dimension, type, title, required, max_choices, max_length, sort_order)
VALUES (@qid, '性格特征', 2, '如果用几个词形容我的性格，你会选哪些？为什么？', 0, 0, 200, 7);
SET @q7 = LAST_INSERT_ID();


-- ---------- 维度四：关系认知 ----------
INSERT INTO question (questionnaire_id, dimension, type, title, required, max_choices, max_length, sort_order)
VALUES (@qid, '关系认知', 1, '在你心里，我们现在更像哪一种关系？', 0, 0, 200, 8);
SET @q8 = LAST_INSERT_ID();
INSERT INTO question_option (question_id, content, sort_order) VALUES
  (@q8, '普通同学 / 同事',       1),
  (@q8, '关系不错的朋友',         2),
  (@q8, '可以聊心事的朋友',       3),
  (@q8, '认识，但不算熟',         4);

INSERT INTO question (questionnaire_id, dimension, type, title, required, max_choices, max_length, sort_order)
VALUES (@qid, '关系认知', 1, '用一种相处场景形容我们，你觉得最接近？', 0, 0, 200, 9);
SET @q9 = LAST_INSERT_ID();
INSERT INTO question_option (question_id, content, sort_order) VALUES
  (@q9, '不常联系，但见面不尴尬',        1),
  (@q9, '有事能互相帮一把',              2),
  (@q9, '能一起玩、一起放松',            3),
  (@q9, '能在学习 / 工作上互相推动',      4),
  (@q9, '无话不谈的那种',                5);

INSERT INTO question (questionnaire_id, dimension, type, title, required, max_choices, max_length, sort_order)
VALUES (@qid, '关系认知', 1, '你觉得我们之间的关系走向更像？', 0, 0, 200, 10);
SET @q10 = LAST_INSERT_ID();
INSERT INTO question_option (question_id, content, sort_order) VALUES
  (@q10, '会一直保持联系的长期朋友',              1),
  (@q10, '阶段性的朋友，各自阶段结束后慢慢变淡',  2),
  (@q10, '现在这样挺好，不去想那么远',            3),
  (@q10, '说不清',                                4);

INSERT INTO question (questionnaire_id, dimension, type, title, required, max_choices, max_length, sort_order)
VALUES (@qid, '关系认知', 2, '如果让你用一句话形容我们的关系，你会说什么？', 0, 0, 200, 11);
SET @q11 = LAST_INSERT_ID();


-- =====================================================================
-- 3. 自检：核对一下写入结果
-- =====================================================================
SELECT '问卷' AS 项目, COUNT(*) AS 数量 FROM questionnaire
UNION ALL
SELECT '题目', COUNT(*) FROM question
UNION ALL
SELECT '选项', COUNT(*) FROM question_option;
-- 期望：问卷 1 / 题目 11 / 选项 40

-- 逐题列出，确认顺序与维度
SELECT q.sort_order AS 顺序,
       q.dimension   AS 维度,
       CASE q.type WHEN 1 THEN '有选项' ELSE '纯自由' END AS 类型,
       q.title       AS 题干,
       (SELECT COUNT(*) FROM question_option o WHERE o.question_id = q.id) AS 选项数
FROM question q
WHERE q.questionnaire_id = @qid
ORDER BY q.sort_order;


-- =====================================================================
-- 4. 记下这两个值，后面调接口要用
-- =====================================================================
SELECT id AS 问卷ID, share_code AS 分享码, owner_token AS 管理凭证
FROM questionnaire
WHERE share_code = @share_code;


-- =====================================================================
-- 附：想给某道题限制最多选几项
--     现在全部是「不限」(max_choices = 0)。第 1 题有 9 个选项，
--     不限量时可能有人全选，分布会失去区分度。想限制就执行：
--
--     UPDATE question SET max_choices = 3 WHERE id = @q1;
--
--     不过更推荐等真实数据出来、看到确实有人全选之后再改
--     （docs/07-题型统一-影响评估.md §6.1 也留了这个决策点）。
-- =====================================================================
