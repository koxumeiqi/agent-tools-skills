---
name: mrd-to-prd-units
description: "将大型 MRD 拆分为多个保持全局意图、依赖关系和共享状态的 PRD 单元。仅当用户以命令形式显式调用 `$mrd-to-prd-units <MRD文件路径>` 时触发。"
---

# MRD 拆分 PRD 单元

本 skill 用于在 **Graphiti MCP 已安装且 MRD 文件路径明确** 的前提下，将大型 MRD 拆分成多个保持全局意图、依赖关系和共享状态的 PRD 单元。

不要在没有 Graphiti MCP 的情况下用纯文本模拟知识图谱。不要在无法识别 MRD 文件路径时继续执行。

## 前置条件

执行前必须同时满足：

1. 用户明确调用 `$mrd-to-prd-units`，或明确要求“使用 mrd-to-prd-units 将某个 MRD 文件拆分成多个关联 PRD 单元”。
2. 当前会话中可以明确识别 MRD 文件路径。
3. Graphiti MCP 已经安装、配置并可用。

如果 MRD 文件路径无法识别，直接拒绝执行并要求用户提供 MRD 文件路径。

如果 Graphiti MCP 不可用，直接拒绝执行并要求用户先安装或启用 Graphiti MCP。不要退化为普通文本拆分，不要使用本地 Markdown/YAML 伪造知识图谱。

## 产物结构

默认在 MRD 同级目录或用户指定输出目录下创建：

```text
prd-units/
  00-global-intent.md
  01-graph-namespace.md
  02-prd-index.md
  units/
    PRD-001-*.md
    PRD-002-*.md
  99-consistency-review.md
```

## 资源

执行时读取：

- `references/prd-template.md`：每个 PRD 单元必须遵循的模板。
- `references/consistency-review-rubric.md`：子 Agent 一致性审查标准。

## 工作流

### 1. 初始化知识图谱命名空间

基于项目名、MRD 文件名和当前时间创建 Graphiti `group_id` 或等价命名空间。

命名空间必须满足：

- 不与其他项目混用。
- 写入 `01-graph-namespace.md`。
- 后续所有 Graphiti 写入和检索都限定在该命名空间内。

`01-graph-namespace.md` 至少记录：

```markdown
# Graph Namespace

- Graph MCP: Graphiti
- Group ID:
- MRD file:
- Created at:
- Output directory:
```

### 2. 提取 MRD

读取 MRD 文件内容。支持 Markdown、纯文本、可解析文档或用户会话中提供的 MRD 内容。

提取以下信息并分批写入 Graphiti：

- MRD 原文或可追溯分块。
- 项目背景。
- 目标用户。
- 业务目标。
- 功能模块。
- 用户流程。
- 用例。
- 流程图、用例图或架构图中的节点与边。
- 技术栈。
- 技术约束。
- 风险、非目标、未决问题。

写入 Graphiti 时保留来源信息。每个后续 PRD 单元都应能追溯到 MRD 来源片段或图谱节点。

### 3. 提取全局意图节点

从 MRD 和 Graphiti 检索结果中建立全局意图层。

至少包含：

- `ProjectGoal`：项目总体目标。
- `CoreIntent`：产品最终意图。
- `TargetUser`：目标用户或用户角色。
- `CoreScenario`：核心场景。
- `NorthStarMetric`：北极星指标或主要成功标准。
- `ProductPrinciple`：不可牺牲的产品原则。
- `TechnicalConstraint`：关键技术约束。
- `NonGoal`：明确不做的内容。

输出 `00-global-intent.md`。该文件是所有 PRD 单元的全局锚点。

### 4. 构建知识图谱

基于 MRD 内容和全局意图层，继续向 Graphiti 写入需求图谱。

建议节点类型：

- `Module`
- `Capability`
- `Workflow`
- `UseCase`
- `DataEntity`
- `Integration`
- `PageOrSurface`
- `APIOrService`
- `Risk`
- `OpenQuestion`
- `PRDUnitCandidate`

建议边类型：

- `serves`
- `depends_on`
- `enables`
- `blocks`
- `shares_entity`
- `constrains`
- `belongs_to_flow`
- `derived_from`
- `impacts`
- `must_align_with`

要求：

- 任何 PRD 候选单元必须至少连接一个 `ProjectGoal`、`CoreIntent` 或 `CoreScenario`。
- 跨模块共享概念必须建成共享实体节点，不要复制成多个互相矛盾的局部定义。
- 发现循环依赖、需求冲突或无法确认的关系时，先记录为 `Risk` 或 `OpenQuestion`，不要擅自消除。

### 5. 拆分 PRD 单元

拆分时不要只按 MRD 章节切分。综合考虑：

- 用户旅程阶段。
- 业务能力边界。
- 数据实体生命周期。
- 系统或服务边界。
- 技术依赖。
- 验收独立性。
- 风险密度。
- 与全局意图的关系。

PRD 单元应尽量细，但必须满足：

- 可独立理解。
- 可独立验收。
- 有明确输入、输出、触发条件或用户动作。
- 上游依赖和下游影响可以说清楚。
- 至少服务一个全局目标或核心场景。

每生成一个 PRD 单元前，必须先从 Graphiti 查询：

- 相关全局目标。
- 相关核心场景。
- 相关模块和能力。
- 上游依赖。
- 下游影响。
- 共享实体。
- 技术约束。
- 风险和未决问题。
- MRD 来源片段或来源节点。

然后按照 `references/prd-template.md` 生成 `units/PRD-xxx-*.md`。

### 6. 生成 PRD 索引

所有 PRD 单元生成完成后，输出 `02-prd-index.md`。

索引至少包含：

```markdown
| PRD | 标题 | 服务的全局目标 | 上游依赖 | 下游影响 | 共享实体 | 状态 |
|---|---|---|---|---|---|---|
```

索引必须帮助后续 Agent 快速理解 PRD 单元之间的关系，而不是只列文件名。

### 7. 启动子 Agent 做一致性审查

所有 PRD 单元完成后，开启一个子 Agent 进行独立一致性审查，用于隔离上下文和降低生成者自我确认偏差。

给子 Agent 的输入只包含：

- MRD 文件或 MRD 摘要。
- `00-global-intent.md`。
- `01-graph-namespace.md`。
- Graphiti 中导出的关键节点和关系摘要。
- `02-prd-index.md`。
- 所有 `units/PRD-*.md`。
- `references/consistency-review-rubric.md`。

不要把本轮拆分过程中的主观推理、选择理由、草稿争论或期望结论提供给子 Agent。

子 Agent 输出写入 `99-consistency-review.md`。

如果当前环境没有可用的子 Agent 工具，改为明确说明无法开启子 Agent，并在主线程使用同一 rubric 做一次有限审查，同时在 `99-consistency-review.md` 标记审查隔离不足。

## 硬性规则

- 没有 Graphiti MCP，不执行。
- 没有可识别的 MRD 文件路径，不执行。
- 不用纯文本、Markdown 或 YAML 模拟知识图谱。
- 不生成没有全局意图链接的 PRD 单元。
- 不生成没有依赖状态说明的 PRD 单元。
- 不把跨模块共享实体复制成多个互相独立的定义。
- 不把无法独立验收的内容作为独立 PRD 单元。
- 不把明显不服务整体目标的内容静默保留；必须标记为 questionable 或放入审查报告。

## 拒绝执行模板

MRD 路径缺失时：

```text
无法执行 $mrd-to-prd-units：当前会话中无法识别 MRD 文件路径。请提供 MRD 文件的完整路径或明确的相对路径。
```

Graphiti MCP 缺失时：

```text
无法执行 $mrd-to-prd-units：当前环境未检测到可用的 Graphiti MCP。请先安装并配置 Graphiti MCP，然后重新调用本 skill。
```
