# Agent 应用开发面试题库 — Java 后端定制版
> 在通用版基础上按 Java 背景重排 | 依据：BOSS直聘 10 个真实岗位（2026-10-27）+ Java AI 生态现状

## 一、你的定位：Java 线在这批岗位里怎么打

### 1. 直接对口你的 BOSS 岗位（优先投这些）
| 岗位 | 为什么对口 Java 后端 |
|---|---|
| 讼牍科技 · AI Agent应用开发（北京，3-5年） | 明确以 Java 为主，Spring 全家桶 + MyBatis + MySQL，用 LangChain/LangGraph/CrewAI 编排、Coze/Dify 落地、pgvector 做检索 |
| 阿里巴巴 · Ai Agent 应用开发（杭州，3-5年） | 标签 Java/MySQL/Spring，做智能运营平台和 AI-Native 研发 |
| BOSS直聘 · agent开发工程师（北京，1-3年） | 标签 Python 但技术栈含 Elasticsearch/MySQL/Redis，职责是 Agent 系统设计与稳定性 |
| 中科创达 · Agent开发工程师（成都，1-3年，硕士） | Java/C++/Python，做研发提效类 Agent（设计生成、单测生成、缺陷分析）+ 工具链集成 |

另外两类也要懂：每日互动（杭州）做 Agent 平台 + Tools/Skills + RPA，法本（广州）用 LangGraph —— 这类岗语言不限，但会拿 Python 生态的概念考你，你要用 Java 的实现方式答回来。

### 2. 你的优势话术（面试开场就这么定位）
> 「我的底座是 Java 后端：Spring Boot/微服务、MySQL/Redis、消息队列、高并发和线上稳定性这些在 Agent 岗里恰恰是地基——JD 里 MySQL 出现 4 次、Spring 被多次点名。Agent 层我补的是 LLM 应用那一层：RAG、Function Calling、Spring AI / LangChain4j、LangGraph 的编排思想。模型训练不是我的主张，应用落地和工程化是。」

这套话术对应第三方对 BOSS 的抽样结论：AI Agent 岗技能词频第一仍是 Java 地基，溢价来自在后端功底上叠 AI 层。**不要和算法岗拼训练，不要和纯 Python 岗拼调包速度，拼系统落地。**

### 3. 优先级重排（和通用版的区别）
- **升到必修：** Spring AI、LangChain4j、WebFlux/SSE 流式、虚拟线程与线程池隔离、pgvector、Spring 生态的可观测（Micrometer/链路追踪）
- **降为了解：** PyTorch 训练细节、Python asyncio 深水区 —— 能讲清概念即可，被问到就大方说「训练侧我能看懂和对接，应用侧我用 Java 落地」
- **保持必修：** RAG 全链路、Function Calling/MCP、Prompt、评测、幻觉与注入治理、多 Agent 概念（LangGraph/CrewAI 是思想，Java 里用状态机/图编排实现）

---

## 二、Java 专属高频题（通用版没有、Java 岗必问）

**QJ1. Spring AI 和 LangChain4j 怎么选？你用过哪个？**
答题要点：
- Spring AI：Spring 官方出品，和 Spring Boot 原生融合——自动配置、依赖注入、ChatClient + Advisors 链、VectorStore 统一抽象、用 Micrometer 做可观测。已有 Spring 技术栈、要企业级规范和可观测，选它。国内还有 Spring AI Alibaba 深度整合通义千问。
- LangChain4j：类 LangChain 的 Java 库，抽象更显式灵活——ChatLanguageModel、@AiService 注解式接口、EmbeddingStore（20+ 向量库集成）、工具与 RAG 组件粒度更细，Spring Boot 和 Quarkus 都能集成。RAG 要深度定制、或不想绑死 Spring，选它。
- **加分答法：** 两者瓶颈都不在框架，而在模型 API 延迟；选型看团队栈和定制深度，不要站队吹一个踩一个。没都用过就只深讲用过的那个，另一个讲选型对比。

**QJ2. 在 Spring AI / LangChain4j 里，Function Calling 落到 Java 代码是什么样？**
答题要点：把一个普通 Java 方法暴露为工具——Spring AI 用 `@Tool` 注解 + 参数描述，LangChain4j 同样支持 `@Tool` 并由 AI Services 自动执行；参数用强类型对象承接（不要 Map 裸奔），框架负责把方法签名转成模型要的 Schema、把模型返回的参数反序列化。执行层你自己负责：参数校验（JSR-380）、鉴权、超时、审计。**强类型 + 校验是 Java 相比动态语言的天然优势，要点出来。**

**QJ3. 结构化输出在 Java 里怎么做？**
答题要点：定义 Java Bean / record 作为目标类型，框架把模型输出直接映射成对象（如 Spring AI 的 BeanOutputConverter、LangChain4j 的 @AiService 返回类型）；底层仍是给模型 Schema 约束 + 输出校验，映射失败要重试/修复，不要自己写正则解析 JSON——面试官问这个就是在筛「还在字符串拼 Prompt」的人。

**QJ4. 流式输出在 Spring 里怎么实现？为什么不能用普通同步接口硬扛？**
答题要点：模型生成是秒级长响应，同步阻塞会占满 Tomcat 线程池。用 WebFlux 的 `Flux<String>` 或 Spring MVC 的 SSE（SseEmitter）逐 token 推给前端；LangChain4j/Spring AI 的流式模型接口都返回响应式流。还要讲：客户端断开要取消上游调用、流式过程中工具调用如何分段、首 token 延迟怎么监控。

**QJ5. LLM 调用是 IO 密集且慢，Java 服务的线程模型怎么设计？**
答题要点（这是 Java 岗的分水岭题）：
- 绝不能让慢速模型调用和核心交易接口共用一个线程池——做**线程池隔离**，模型调用单独池 + 有界队列 + 超时熔断（Resilience4j）
- Java 21 **虚拟线程**很适合这种高并发 IO 场景：一个请求一个虚拟线程写同步式代码，吞吐接近异步但可读性好；注意别在 synchronized/原生调用上 pin 住载体线程
- 或全链路 WebFlux 响应式，但要接受调试和上下文传递（TraceId、安全上下文）的复杂度
- 上游模型有配额：限流、排队、重试退避、多模型路由降级都要在这一层做

**QJ6. RAG 在 Java 栈里怎么落地？向量库为什么很多 Java 团队选 pgvector？**
答题要点：入库用 Spring AI 的 ETL 三件套（DocumentReader → Transformer 切分 → Writer 入 VectorStore）或 LangChain4j 的 DocumentSplitter + EmbeddingStore；检索走 VectorStore 统一抽象，换 Milvus/pgvector/Elasticsearch 不改业务代码。pgvector 的卖点：团队已有 PostgreSQL 运维能力、事务和业务数据同库、按权限做元数据过滤就是一条 SQL 的事——讼牍科技 JD 里写的就是 pgvec。数据量到千万级以上再谈 Milvus 这类专用库。

**QJ7. 会话记忆在 Java 服务里存哪？多实例部署怎么办？**
答题要点：短期记忆不要放 JVM 本地内存（多实例就穿帮），放 Redis 并设 TTL；框架侧 Spring AI 有 ChatMemory 抽象、LangChain4j 有 ChatMemory 接口，都能接 Redis/DB 实现。长期记忆走数据库 + 向量召回。并发下同一会话多请求要做顺序/锁控制，别让两轮对话交叉污染上下文。

**QJ8. Java 做 Agent 编排，和 LangGraph 的图/状态机思想怎么对应？**
答题要点：LangGraph 的本质是显式状态机——节点、条件边、共享 State、Checkpoint 断点续跑。Java 里：简单流程用 Spring AI Advisors 链或责任链；复杂有状态流程可以自研状态机、或用 Spring Statemachine / 工作流引擎承接同一思想，部分团队是 Java 主系统 + Python 编排服务通过 API/MCP 互调（讼牍科技 JD 就是 Java 主开发同时用 LangGraph/CrewAI）。**答题关键是讲清思想，别假装 Java 里有个一模一样的 LangGraph。**

**QJ9. MCP 在 Java 里怎么接？**
答题要点：Spring AI 已有 MCP Client/Server 的支持（可把 Java 服务暴露为 MCP Server，也可作为 Client 调用外部工具）；价值对 Java 团队尤其大——存量系统（订单、库存、CRM 的 Spring 服务）不用重写，包一层 MCP 就能被任何 Agent 调用。工具权限仍在服务端收口，MCP 不是免鉴权的后门。

**QJ10. 可观测和评测在 Spring 生态怎么做？**
答题要点：Micrometer + OpenTelemetry 记录每次调用的模型、token 用量、耗时、工具成功率，TraceId 贯穿「用户请求 → 检索 → 模型 → 工具」全链；评测集做成自动化测试的一环（JUnit + 固定 case 集，跑在 CI 的夜间任务里），改 Prompt/换模型必须过回归门槛。把 Agent 当普通微服务来治理，是 Java 背景最自然的加分项。

---

## 三、从通用版保留的核心题（答法按 Java 视角微调）

以下只给 Java 版要点，完整框架看通用版对应题号：

- **RAG 翻车排查（通用版 Q10-Q13）：** 排查顺序不变，落点换成 Java 实现：混合检索 = 向量召回 + Elasticsearch BM25，Rerank 用独立模型服务调用，权限过滤在 SQL/查询层做。
- **工具选错/死循环治理（Q7/Q9/Q17）：** 在 Java 侧落成：工具路由服务、调用次数计数器放 Redis、每步结果校验用拦截器/Advisors 做切面。
- **成本与模型路由（Q21）：** 路由层就是一个 Spring 服务：按任务难度分发到大/小模型，结果缓存用 Redis，账算到每次请求的 token 成本字段里。
- **微调（Q2/Q20）：** Java 岗对微调的要求是**理解 + 对接**：说清 LoRA/QLoRA 何时该用、数据格式、如何调用训练/部署后的模型服务并做 A/B 对比即可，不要求你现场用 Java 训模型。讼牍科技 JD 里的 QLoRA 属于这一类。
- **系统设计题（Q28/Q29）：** 直接用你的微服务话术答：网关限流 → Agent 编排服务 → 检索服务 → 工具服务（各自独立部署、熔断降级），这套拆分 Java 面试官最买账。
- **多 Agent（Q18）：** 概念照答，补一句落地形态：多 Agent 在 Java 团队常是多个微服务各司其职 + 消息队列/事件驱动协作，而不是一个进程里跑 CrewAI。

## 四、给你量身的补短板计划（2 周，每天 2-3 小时）

**做一个能讲 20 分钟的 Java Agent 项目（没现成项目就做这个，别只看书）：**
> Spring Boot 3 + Spring AI（或 LangChain4j，二选一深做）+ pgvector + Redis
> 功能：企业文档知识库 Agent —— 文档入库切分、混合检索问答带引用、一个业务工具调用（如查数据库里的订单/工单）、SSE 流式输出、Redis 会话记忆、Micrometer 记录 token 与耗时、20 条自建评测集
> 这个项目恰好覆盖讼牍科技和阿里两个 JD 的大部分关键词，面试时所有题都能落回它。

- 第 1-4 天：跑通项目主链路（入库 → 检索 → 问答 → 流式）
- 第 5-7 天：加工具调用 + 会话记忆 + 异常兜底（超时、重试、转人工话术）
- 第 8-10 天：RAG 深挖——切分策略对比、混合检索、Rerank、Recall 评测，把数据记下来
- 第 11-12 天：Java 工程题复习——虚拟线程/线程池隔离、WebFlux、MySQL 索引事务、Redis、Kafka 幂等，这部分是你主场，要答得比 AI 题还稳
- 第 13-14 天：用项目过一遍通用版「项目深挖 8 问」，每问写出带数字的答案

## 五、1 分钟自我介绍模板（Java 版，填空即用）

> 「我有 [X] 年 Java 后端经验，主要做 [业务系统类型]，技术栈是 Spring Boot/微服务、MySQL、Redis、[Kafka/RabbitMQ]，负责过 [一个能说出量级的系统：如日均 X 万请求 / X 个服务]。
> 最近一年我把方向叠到大模型应用上：用 [Spring AI / LangChain4j] 做了 [RAG 知识库 / 工具调用 Agent 项目名]，实现了 [文档检索问答 + Function Calling 调业务接口]，把 [某个指标：如客服答复时间/人工工单量] 从 [ ] 降到 [ ]。
> 我应聘 Agent 岗的优势是工程落地：模型会失败、会超时、会超成本，我的经验正好是把这种不确定系统做成稳定可观测的线上服务。」

没有真实指标的地方宁可留白现场说明，也不要编数字——Java 岗面试官追问系统细节的深度，编的数字两问就穿。


