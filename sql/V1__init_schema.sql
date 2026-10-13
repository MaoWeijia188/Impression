-- =====================================================================
--  印象问答 Impression · V1 初始化表结构
-- ---------------------------------------------------------------------
--  目标库    : MySQL 8.4
--  引擎      : InnoDB
--  字符集    : utf8mb4 / utf8mb4_0900_ai_ci
--  可重复执行: 是（每次执行都会把 impression 库推倒重建）
--  执行方式  : MySQL Workbench → 新建 Query Tab → 全选粘贴 → 点 ⚡ 执行
--
--  ⚠️ 危险提示
--  本脚本第 0 步是 DROP DATABASE。它只作用于名为 `impression` 的库，
--  不会碰你机器上其它数据库。但一旦这个库里已经有了真实回答数据，
--  重跑就会全部丢失，且不可恢复。
--      · 第一次建库：随便跑。
--      · 收到真实回答之后：不要再跑这个文件，改用 ALTER 脚本增量改表
--        （约定见 docs/03-数据库设计.md §8 变更管理）。
-- =====================================================================


-- ---------------------------------------------------------------
-- 0. 清空并重建数据库
-- ---------------------------------------------------------------
DROP DATABASE IF EXISTS impression;

CREATE DATABASE impression
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE impression;

-- 显式声明客户端字符集。Workbench 某些连接默认是 latin1，
-- 不写这一行的话，脚本里的中文（题干、选项、注释）会存成乱码。
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;


-- ---------------------------------------------------------------
-- 1. questionnaire 问卷
-- ---------------------------------------------------------------
CREATE TABLE questionnaire (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  owner_token CHAR(43)        NOT NULL                COMMENT '创建者凭证(Base64URL 编码的 32 字节随机数)。不唯一：同一个人可创建多份问卷',
  title       VARCHAR(30)     NOT NULL                COMMENT '问卷标题',
  description VARCHAR(100)    NOT NULL DEFAULT ''     COMMENT '问卷描述',
  share_code  CHAR(11)        NOT NULL                COMMENT '分享码(Base64URL 编码的 8 字节随机数)，公开链接 /u/{share_code} 用它',
  status      TINYINT         NOT NULL DEFAULT 1      COMMENT '状态：1=进行中，2=已关闭',
  created_at  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uk_questionnaire_share_code (share_code),
  KEY idx_questionnaire_owner (owner_token, created_at)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '问卷';


-- ---------------------------------------------------------------
-- 2. question 题目
--
-- 题型已统一（v2.0）：每题都可以「多选 + 自定义答案 + 跳过」，
-- 所以 type 只用来区分「有没有预设选项」，不再区分单选/多选/开放。
-- ---------------------------------------------------------------
CREATE TABLE question (
  id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  questionnaire_id BIGINT UNSIGNED NOT NULL                COMMENT '所属问卷',
  dimension        VARCHAR(20)     NOT NULL DEFAULT ''     COMMENT '所属维度：第一印象 / 相处体验 / 性格特征 / 关系认知。结果页按它分组',
  type             TINYINT         NOT NULL DEFAULT 1      COMMENT '展示类型：1=有预设选项，2=纯自由填写（不再表示单选/多选/开放）',
  title            VARCHAR(200)    NOT NULL                COMMENT '题干',
  description      VARCHAR(200)    NOT NULL DEFAULT ''     COMMENT '题干补充说明',
  required         TINYINT         NOT NULL DEFAULT 0      COMMENT '是否必答：1=必答 0=可跳过。v2.0 起全部可跳过，本字段恒为 0，仅供将来恢复差异化设置',
  max_choices      TINYINT         NOT NULL DEFAULT 0      COMMENT '最多可选数：0=不限（注意：早期设计稿默认值是 1，沿用会让多选静默失效）',
  max_length       SMALLINT        NOT NULL DEFAULT 200    COMMENT '自定义答案字数上限；0=不允许自定义',
  sort_order       SMALLINT        NOT NULL DEFAULT 0      COMMENT '展示顺序，从 1 开始',
  created_at       DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at       DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_question_q_sort (questionnaire_id, sort_order),
  CONSTRAINT fk_question_questionnaire
    FOREIGN KEY (questionnaire_id) REFERENCES questionnaire (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '题目';


-- ---------------------------------------------------------------
-- 3. question_option 题目的选项
-- ---------------------------------------------------------------
CREATE TABLE question_option (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  question_id BIGINT UNSIGNED NOT NULL                COMMENT '所属题目',
  content     VARCHAR(50)     NOT NULL                COMMENT '选项文案',
  sort_order  SMALLINT        NOT NULL DEFAULT 0      COMMENT '展示顺序',
  created_at  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_option_q_sort (question_id, sort_order),
  CONSTRAINT fk_option_question
    FOREIGN KEY (question_id) REFERENCES question (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '题目的选项';


-- ---------------------------------------------------------------
-- 4. submission 一次完整答题
-- ---------------------------------------------------------------
CREATE TABLE submission (
  id                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  questionnaire_id   BIGINT UNSIGNED NOT NULL                COMMENT '所属问卷',
  submit_token       CHAR(36)        NOT NULL                COMMENT '提交幂等键(UUID v4)，前端生成；唯一索引保证重复点击只落一条',
  client_fingerprint CHAR(64)        NULL                    COMMENT 'IP+UA 的 SHA-256 十六进制摘要，仅用于风控去重，不存明文（默认不采集）',
  duration_ms        INT UNSIGNED    NULL                    COMMENT '答题耗时(毫秒)，用于分析题目流失',
  created_at         DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uk_submission_token (submit_token),
  KEY idx_submission_q_created (questionnaire_id, created_at),
  KEY idx_submission_q_fingerprint (questionnaire_id, client_fingerprint),
  CONSTRAINT fk_submission_questionnaire
    FOREIGN KEY (questionnaire_id) REFERENCES questionnaire (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '一次答题提交';


-- ---------------------------------------------------------------
-- 5. answer 单题答案
--
-- 「跳过」= 不插入这一行。不引入 is_skipped 之类的冗余状态字段。
-- ---------------------------------------------------------------
CREATE TABLE answer (
  id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  submission_id BIGINT UNSIGNED NOT NULL                COMMENT '所属提交',
  question_id   BIGINT UNSIGNED NOT NULL                COMMENT '对应题目',
  text_content  VARCHAR(200)    NULL                    COMMENT '自定义/自由答案文本，任何题都可能填；未填为 NULL。选中项另存 answer_option。未作答则不插入本行',
  created_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uk_answer_submission_question (submission_id, question_id),
  KEY idx_answer_question (question_id),
  CONSTRAINT fk_answer_submission
    FOREIGN KEY (submission_id) REFERENCES submission (id) ON DELETE CASCADE,
  CONSTRAINT fk_answer_question
    FOREIGN KEY (question_id) REFERENCES question (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '单题答案';


-- ---------------------------------------------------------------
-- 6. answer_option 被选中的选项
--
-- question_id 是有意识的冗余（反范式）：统计「某题各选项票数」时
-- 可以少一次 join。代价是写入时必须由 Service 在同一事务内保证它
-- 与 answer.question_id 一致。
-- ---------------------------------------------------------------
CREATE TABLE answer_option (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  answer_id   BIGINT UNSIGNED NOT NULL                COMMENT '所属答案',
  question_id BIGINT UNSIGNED NOT NULL                COMMENT '冗余字段：便于直接按题目统计，省掉一次 join',
  option_id   BIGINT UNSIGNED NOT NULL                COMMENT '被选中的选项',
  sort_no     TINYINT         NULL                    COMMENT '预留：排序题的位次；单选/多选为 NULL',
  created_at  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uk_answer_option (answer_id, option_id),
  KEY idx_ao_option (option_id),
  KEY idx_ao_question (question_id),
  CONSTRAINT fk_ao_answer
    FOREIGN KEY (answer_id) REFERENCES answer (id) ON DELETE CASCADE,
  CONSTRAINT fk_ao_question
    FOREIGN KEY (question_id) REFERENCES question (id) ON DELETE CASCADE,
  CONSTRAINT fk_ao_option
    FOREIGN KEY (option_id) REFERENCES question_option (id) ON DELETE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci COMMENT = '被选中的选项';


-- ---------------------------------------------------------------
-- 7. 自检：应当列出 6 张表
-- ---------------------------------------------------------------
SELECT TABLE_NAME AS '表名', TABLE_COMMENT AS '说明'
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'impression'
ORDER BY TABLE_NAME;
