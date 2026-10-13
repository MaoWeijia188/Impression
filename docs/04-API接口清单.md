# 印象问答 · API 接口清单

关联：`01-产品需求文档.md`、`03-数据库设计.md`

后端：Spring Boot 4.1.x ｜ 统一前缀 `/api` ｜ 数据格式 `application/json; charset=utf-8`

---

## 1. 通用约定

### 1.1 接口分组与鉴权

| 分组 | 前缀 | 鉴权 | 说明 |
|---|---|---|---|
| 公开接口 | `/api/public/**` | **无需鉴权** | 答题者使用，只暴露必要信息，**绝不返回统计结果或提交明细** |
| 管理接口 | `/api/manage/**` | 需要请求头 `X-Owner-Token: {ownerToken}` | 创建者使用 |

> 第一版没有账号体系，`ownerToken` 就是创建者的全部身份凭据。
> 服务端实现建议用 Spring 的 `HandlerInterceptor` 或 `OncePerRequestFilter` 统一校验，**不要在每个 Controller 里手写判断**（漏一个就是一个越权漏洞）。

### 1.2 统一响应体

成功：

```json
{ "code": 0, "message": "ok", "data": { } }
```

失败：

```json
{ "code": 40901, "message": "这份问卷已经停止收集了", "data": null }
```

- `code = 0` 表示业务成功；非 0 表示失败。
- HTTP 状态码同时给出语义化状态（400 / 401 / 403 / 404 / 409 / 429 / 500）。
- `message` 面向**最终用户**可读，前端可直接展示。
- 实现方式：`@RestControllerAdvice` 全局异常处理 + 自定义 `BizException`。

### 1.3 错误码表

| code | HTTP | 含义 | 前端处理建议 |
|---|---|---|---|
| 0 | 200 | 成功 | — |
| 40001 | 400 | 参数校验失败 | Toast 提示 message |
| 40002 | 400 | 请求体格式错误 | Toast |
| 40101 | 401 | 缺少创建者凭证 | 引导输入 ownerToken |
| 40301 | 403 | 凭证无效 / 无权访问该资源 | 清除本地凭证并提示 |
| 40401 | 404 | 问卷不存在 | 显示 404 态 |
| 40402 | 404 | 分享码无效 | 「链接无效」错误态 |
| 40403 | 404 | 提交记录不存在 | Toast + 刷新列表 |
| 40901 | 409 | 问卷已关闭，无法提交 | 「已停止收集」错误态 |
| 42901 | 429 | 请求过于频繁 | Toast「操作太频繁，稍后再试」 |
| 50000 | 500 | 服务器内部错误 | 通用错误提示，不要暴露堆栈 |

> **幂等不报错**：相同 `submitToken` 重复提交时，返回 `200` 且 `duplicated = true`，而不是抛 409。这样「网络抖动导致前端重试」不会变成用户可见的错误。

### 1.4 分页约定

请求：`?page=1&size=10`（`page` 从 1 开始，`size` 上限 50，默认 10）

响应：

```json
{
  "code": 0,
  "message": "ok",
  "data": {
    "list": [],
    "page": 1,
    "size": 10,
    "total": 42
  }
}
```

### 1.5 其他约定

| 项 | 约定 |
|---|---|
| 时间格式 | ISO 8601 带时区：`2026-10-12T19:30:00+08:00` |
| 字段命名 | camelCase（Jackson 默认 + `PropertyNamingStrategies`） |
| 长文本 | 开放题上限 200 字，前端与后端**双重校验** |
| 防重复提交 | 前端生成 UUID v4 作为 `submitToken`，后端靠唯一索引兜底 |
| 限流 | 提交接口按 IP 限流（如 10 次/分钟），触发返回 42901 |
| XSS | 后端统一对开放题文本做转义/白名单，前端展示时不再拼 HTML |

---

## 2. 公开接口（答题者）

### P-01 获取问卷基本信息

```
GET /api/public/questionnaires/{shareCode}
```

**路径参数**：`shareCode` — 分享码

**响应 `data`**

```json
{
  "title": "维嘉的印象问答",
  "description": "花 1 分钟，告诉我你眼中的我是什么样的人",
  "status": 1,
  "questionCount": 11,
  "estimatedSeconds": 60
}
```

**错误**：`40402` 分享码无效

> 若问卷已关闭（status=2），本接口**仍返回 200**，让前端能显示「已停止收集」的友好提示，而不是一个冷冰冰的 404。

---

### P-02 获取题目与选项

```
GET /api/public/questionnaires/{shareCode}/questions
```

**响应 `data`**

```json
{
  "questions": [
    {
      "id": 1,
      "type": 1,
      "title": "你第一次见我时，觉得我是一个什么样的人？",
      "description": "",
      "required": true,
      "maxChoices": 1,
      "maxLength": 0,
      "options": [
        { "id": 11, "content": "安静、有点慢热" },
        { "id": 12, "content": "健谈、比较外向" },
        { "id": 13, "content": "看起来很有想法" },
        { "id": 14, "content": "随和、好相处" },
        { "id": 15, "content": "说不清楚，没太多印象" }
      ]
    },
    {
      "id": 2,
      "type": 2,
      "title": "你觉得我最突出的三个特点是什么？（最多选 3 项）",
      "description": "",
      "required": true,
      "maxChoices": 3,
      "maxLength": 0,
      "options": [
        { "id": 21, "content": "独立，有自己的想法" },
        { "id": 22, "content": "幽默，会活跃气氛" }
      ]
    },
    {
      "id": 9,
      "type": 3,
      "title": "有什么一直想对我说、却没说过的话吗？",
      "description": "可以跳过",
      "required": false,
      "maxChoices": 0,
      "maxLength": 200,
      "options": []
    }
  ]
}
```

**注意**：开放题的 `options` 返回空数组；**不返回**任何票数、统计信息。

---

### P-03 提交回答（核心接口）

```
POST /api/public/questionnaires/{shareCode}/submissions
Content-Type: application/json
```

**请求体**

```json
{
  "submitToken": "8f1c2c7e-2a44-4a2e-9c1b-7d3f9c0b1a55",
  "durationMs": 63210,
  "answers": [
    { "questionId": 1, "optionIds": [13] },
    { "questionId": 2, "optionIds": [21, 23, 25] },
    { "questionId": 9, "text": "其实你有时候想得太多，有些事情可以先做起来。" }
  ]
}
```

| 字段 | 必填 | 校验规则 |
|---|---|---|
| `submitToken` | 是 | UUID v4 格式；**幂等键** |
| `durationMs` | 否 | 从开始答题到提交的毫秒数 |
| `answers` | 是 | 数组 |
| `answers[].questionId` | 是 | 必须属于该问卷 |
| `answers[].optionIds` | 选择题必填 | 每个 option 必须属于该 question；数量 ≤ `max_choices` |
| `answers[].text` | 开放题必填 | 长度 ≤ `max_length`（默认 200） |

**服务端必须校验（这是这个接口的技术含量所在）**

1. 问卷存在且 `status = 1`（在同一事务内校验，避免竞态）
2. 每个 `questionId` 属于该问卷
3. 每个 `optionId` 属于对应的 `questionId`（防伪造）
4. 必答题均已作答；选择题选项数量不超过 `max_choices`
5. 开放题文本长度 ≤ `max_length`，并做 XSS 过滤
6. `submitToken` 唯一；重复则直接返回已存在的提交（幂等）

**响应 `data`**

```json
{ "submissionId": 1024, "duplicated": false }
```

**错误**：`40402` / `40901`（问卷已关闭）/ `40001` / `42901`

---

## 3. 管理接口（创建者）

> 全部需要请求头 `X-Owner-Token: {ownerToken}`

### M-01 创建问卷

```
POST /api/manage/questionnaires
```

**请求体**

```json
{
  "title": "维嘉的印象问答",
  "description": "花 1 分钟，告诉我你眼中的我是什么样的人",
  "preset": "default"
}
```

| 字段 | 必填 | 说明 |
|---|---|---|
| `title` | 是 | ≤ 30 字 |
| `description` | 否 | ≤ 100 字 |
| `preset` | 否 | 第一版固定用预置题库 `default`（11 题）；服务端据此复制题目与选项 |

**若请求头已带合法 `X-Owner-Token`**，新问卷复用该 token；否则服务端生成一个新的。

**响应 `data`**

```json
{
  "id": 1,
  "ownerToken": "Uy8kQ2mZ...（43 位）",
  "shareCode": "aB3xK9mQp",
  "shareUrl": "https://你的域名/u/aB3xK9mQp",
  "manageUrl": "https://你的域名/manage?token=Uy8kQ2mZ..."
}
```

> ⚠️ `ownerToken` 只在创建时返回一次。前端必须写入 `localStorage`，并提示用户**自行备份管理链接**（丢了无法找回，这是第一版刻意接受的代价）。

---

### M-02 我的问卷列表

```
GET /api/manage/questionnaires
```

**响应 `data`**

```json
{
  "list": [
    {
      "id": 1,
      "title": "维嘉的印象问答",
      "status": 1,
      "shareCode": "aB3xK9mQp",
      "submissionCount": 18,
      "createdAt": "2026-10-12T19:30:00+08:00"
    }
  ]
}
```

---

### M-03 问卷详情

```
GET /api/manage/questionnaires/{id}
```

返回问卷基本信息 + 题目与选项（结构同 P-02，另含 `status`、`shareCode`、`submissionCount`）。

**错误**：`40401` / `40301`（该问卷不属于当前 token）

---

### M-04 更新问卷信息

```
PATCH /api/manage/questionnaires/{id}
```

```json
{ "title": "新标题", "description": "新描述" }
```

**错误**：`40401` / `40301` / `40001`

---

### M-05 开启 / 关闭问卷

```
PATCH /api/manage/questionnaires/{id}/status
```

```json
{ "status": 2 }
```

`status`：1=进行中，2=已关闭。关闭后 P-03 提交接口返回 `40901`。

---

### M-06 删除问卷

```
DELETE /api/manage/questionnaires/{id}
```

级联删除题目、选项、提交与答案（数据库外键 `ON DELETE CASCADE` 完成）。

> **建议前端二次确认**，文案明确写出「将同时删除全部 N 条回答，且不可恢复」。

---

### M-07 统计数据（管理页核心）

```
GET /api/manage/questionnaires/{id}/statistics
```

**响应 `data`**

```json
{
  "sampleSize": 18,
  "enoughSample": true,
  "questions": [
    {
      "questionId": 1,
      "type": 1,
      "title": "你第一次见我时，觉得我是一个什么样的人？",
      "answeredCount": 18,
      "options": [
        { "optionId": 13, "content": "看起来很有想法", "votes": 9, "percent": 50.0 },
        { "optionId": 11, "content": "安静、有点慢热", "votes": 5, "percent": 27.8 },
        { "optionId": 14, "content": "随和、好相处", "votes": 3, "percent": 16.7 },
        { "optionId": 12, "content": "健谈、比较外向", "votes": 1, "percent": 5.6 },
        { "optionId": 15, "content": "说不清楚，没太多印象", "votes": 0, "percent": 0.0 }
      ]
    },
    {
      "questionId": 9,
      "type": 3,
      "title": "有什么一直想对我说、却没说过的话吗？",
      "answeredCount": 12
    }
  ],
  "card": {
    "sampleSize": 18,
    "topTrait": "独立，有自己的想法",
    "topFirstImpression": "看起来很有想法",
    "contrast": null,
    "hint": "样本量较少时 contrast 为 null，前端不展示该行"
  }
}
```

**必须遵守的产品规则（与 PRD §4.2 对应）**

| 规则 | 服务端行为 |
|---|---|
| 样本 < 3 | `enoughSample = false`，`card` 只返回 `sampleSize`，其余字段为 `null` |
| 不把个例说成共识 | 前端展示「有 N 位朋友提到」而不是「大家都觉得」 |
| 有分歧如实呈现 | 当同一题最高票与次高票接近（如差值 ≤ 10%）时，`contrast` 返回分歧描述而非结论 |

---

### M-08 开放题回答列表

```
GET /api/manage/questionnaires/{id}/open-answers?questionId=9&page=1&size=10
```

**响应 `data`**

```json
{
  "list": [
    {
      "answerId": 501,
      "textContent": "其实你有时候想得太多，有些事情可以先做起来。",
      "submittedAt": "2026-10-12T19:45:12+08:00"
    }
  ],
  "page": 1,
  "size": 10,
  "total": 12
}
```

> 只返回文本与时间，**不返回任何可识别答题者的信息**。

---

### M-09 提交明细

```
GET /api/manage/questionnaires/{id}/submissions?page=1&size=10
```

**响应 `data`**

```json
{
  "list": [
    {
      "submissionId": 1024,
      "submittedAt": "2026-10-12T19:45:12+08:00",
      "durationMs": 63210,
      "answers": [
        { "questionId": 1, "type": 1, "selectedOptions": ["看起来很有想法"] },
        { "questionId": 2, "type": 2, "selectedOptions": ["独立，有自己的想法", "理性，喜欢分析问题"] },
        { "questionId": 9, "type": 3, "textContent": "其实你有时候想得太多……" }
      ]
    }
  ],
  "page": 1,
  "size": 10,
  "total": 18
}
```

---

### M-10 删除单条提交

```
DELETE /api/manage/submissions/{submissionId}
```

**错误**：`40403` / `40301`（该提交不属于当前 token 名下的问卷）

---

## 4. 完整调用链路示例

### 4.1 创建者：创建 → 分享

```bash
# 1. 创建问卷
curl -X POST https://localhost:8080/api/manage/questionnaires \
  -H "Content-Type: application/json" \
  -d '{"title":"维嘉的印象问答","description":"一分钟，匿名","preset":"default"}'

# 响应里拿到 ownerToken 与 shareCode，例如 shareCode = aB3xK9mQp

# 2. 用凭证查看自己的问卷列表
curl https://localhost:8080/api/manage/questionnaires \
  -H "X-Owner-Token: Uy8kQ2mZ..."

# 3. 关闭问卷
curl -X PATCH https://localhost:8080/api/manage/questionnaires/1/status \
  -H "X-Owner-Token: Uy8kQ2mZ..." \
  -H "Content-Type: application/json" \
  -d '{"status":2}'
```

### 4.2 答题者：打开 → 答题 → 提交

```bash
# 1. 打开分享链接，先看基本信息
curl https://localhost:8080/api/public/questionnaires/aB3xK9mQp

# 2. 取题目
curl https://localhost:8080/api/public/questionnaires/aB3xK9mQp/questions

# 3. 提交
curl -X POST https://localhost:8080/api/public/questionnaires/aB3xK9mQp/submissions \
  -H "Content-Type: application/json" \
  -d '{
        "submitToken": "8f1c2c7e-2a44-4a2e-9c1b-7d3f9c0b1a55",
        "durationMs": 63210,
        "answers": [
          {"questionId": 1, "optionIds": [13]},
          {"questionId": 2, "optionIds": [21,23,25]},
          {"questionId": 9, "text": "其实你有时候想得太多。"}
        ]
      }'

# 4. 重复执行第 3 步 → 返回 200 且 duplicated=true（不会再写一条）
```

### 4.3 创建者：查看统计

```bash
curl "https://localhost:8080/api/manage/questionnaires/1/statistics" \
  -H "X-Owner-Token: Uy8kQ2mZ..."
```

---

## 5. 接口与页面的对应关系

| 页面 | 调用的接口 |
|---|---|
| `/` 首页 | 无 |
| `/create` 创建 | M-01 |
| `/u/:shareCode` 答题页 | P-01、P-02、P-03 |
| `/u/:shareCode/done` | 无（仅前端状态） |
| `/manage` 管理首页 | M-02、M-05、M-06 |
| `/manage/q/:id` 概览统计 | M-03、M-07 |
| `/manage/q/:id` 回答明细 | M-09、M-08、M-10 |
| `/manage/q/:id` 结果卡片 | M-07（`card` 字段） |

---

## 6. 实现清单（写代码时照着搭）

| 类 | 职责 |
|---|---|
| `GlobalExceptionHandler` | `@RestControllerAdvice`，统一把异常转成 `{code,message,data}` |
| `BizException` | 业务异常，携带错误码 |
| `ApiResponse<T>` | 统一响应包装 `{code, message, data}` |
| `OwnerTokenInterceptor` | 拦 `/api/manage/**`，校验 `X-Owner-Token` |
| `RateLimitFilter` | 提交接口按 IP 限流 |
| `QuestionnaireController` | P-01、P-02、M-03、M-04、M-05、M-06 |
| `SubmissionController` | P-03、M-09、M-10 |
| `StatisticsController` | M-07、M-08 |
| `SubmissionService` | **核心业务**：事务内的校验 + 写入 + 幂等处理 |
| `StatisticsService` | 聚合统计与 `card` 生成规则（含样本量门槛） |
