// ─────────────────────────────────────────────────────────────────────────────
// Boss Spider (boss-spider) — 集中文案配置文件
// 提示：如需修改页面任何文案，只需在此文件中直接修改即可。
// 支持富文本标签：
// - <cyan>文字</cyan>    : 亮蓝色高亮
// - <emerald>文字</emerald> : 翠绿色高亮
// - <amber>文字</amber>   : 琥珀橙高亮
// - <b>文字</b>       : 高亮加粗
// ─────────────────────────────────────────────────────────────────────────────

export const BOSS_SPIDER_COPY = {
  // 顶部导航与通用
  nav: {
    backText: '返回作品集',
    tagline: 'JOB MARKET INTELLIGENCE // 2026 · Boss 直聘职位采集与数据分析平台',
    sections: {
      intro: '01 简介',
      bg: '02 背景',
      demo: '03 演示',
      results: '04 结果',
    },
    backToTop: '[ ↑ Back to Top ]',
  },

  // 01. 简介 (INTRODUCTION)
  intro: {
    sectionTag: '01 / INTRO',
    title: 'Boss Spider 职位情报',
    description:
      '本页面展示了 Boss 直聘职位采集引擎与数据可视化看板构成的<b>完整数据闭环</b>。项目通过基于 Python + Selenium 的<cyan>参数化抓取引擎</cyan>，将 BOSS直聘 上非结构化的职位页面清洗为结构化数据并持久化入库，再以<emerald>ECharts 多维交叉分析</emerald>呈现市场薪资、区域聚集与赛道热度的全局洞察，实现了从"打开网页手动翻"到"一键跑数、看板直达"的<b>自动化数据情报闭环</b>。',
    scrollPrompt: '[ Explore Background & Challenges ↓ ]',
  },

  // 02. 项目背景 (BACKGROUND)
  background: {
    sectionTag: '02 / BACKGROUND',
    title: '项目背景',
    painPoint1: {
      tag: '现状解构 // LEGACY SCRAPERS',
      title: '既有爬虫脚本的失效与脆弱',
      desc: '市面上的开源爬虫脚本大多依赖写死的 DOM 定位，页面一改版就<b>集体失效</b>；同时缺乏参数化配置与反爬处理，面对 BOSS直聘 的动态渲染、登录弹窗与自动化检测，常常<amber>抓取中断或数据残缺</amber>，且长期无人维护。',
      bullets: [
        '既有脚本 DOM 定位写死，<amber>页面改版即失效</amber>',
        '缺乏参数化与反爬处理，<amber>抓取过程脆弱易断</amber>',
      ],
      footerTag: 'BROKEN SCRAPERS',
    },
    painPoint2: {
      tag: '体验困境 // MARKET OPACITY',
      title: '求职市场的经验黑箱',
      desc: '岗位薪资、公司规模、融资阶段、区域聚集度等信息散落在海量职位卡片中，靠人工翻阅<b>很难形成全局认知</b>。求职过程往往只关注"投没投"，缺乏对市场薪酬分布与赛道热度的量化判断，难以回答<amber>"这个薪资是否合理、这个赛道是否热门"</amber>。',
      bullets: [
        '岗位信息散落海量卡片，<amber>缺乏全局数据视角</amber>',
        '薪酬与赛道判断依赖直觉，<amber>缺乏量化依据</amber>',
      ],
      footerTag: 'MARKET OPACITY',
    },
    pipelineCanvas: {
      title: '页面碎片 → 统一数据底座 · Standardization Pipeline',
      subtitle: '看杂乱无章的职位卡片，如何穿过采集管道归整为可视化的市场洞察',
      rawTitle: '原始页面 / Fragmented',
      rawItems: [
        '散落的职位卡片',
        '时薪/日薪/月薪口径不一',
        '登录弹窗与反爬拦截',
        '重复岗位与脏数据',
        '凭直觉判断薪资合理性',
        '难以对比赛道热度',
      ],
      pipeTitle: '采集管道 · 秩序重构',
      pipeSub: 'Selenium 模拟 / 结构化抽取 / 去重入库',
      cleanTitle: '统一数据底座 / Unified',
      cleanItems: [
        { label: '参数化抓取引擎', code: 'SPIDER_ENGINE' },
        { label: '结构化职位模型', code: 'JOB_SCHEMA' },
        { label: 'ECharts 分析看板', code: 'ANALYTICS_DASH' },
      ],
    },
  },

  // 03. 演示 (DEMO)
  demo: {
    sectionTag: '03 / DEMO',
    decorTag: 'TWO CORE SEGMENTS // CRAWLER ENGINE × DATA DASHBOARD',

    // Part 1: 参数化抓取引擎
    part1: {
      sectionTag: 'SEGMENT 1 // CRAWLER ENGINE',
      title: '参数化抓取引擎',
      subtitle: '模拟真人浏览的自动化采集流水线',
      desc: '基于 Selenium 驱动真实浏览器，剥离"正受到自动化控制"特征并注入脚本隐藏 webdriver 属性以降低风控概率；内置<cyan>登录弹窗自动识别关闭</cyan>、<cyan>滚动加载</cyan>与<cyan>翻页等待</cyan>，支持目标城市、岗位大类/子类、多关键字循环队列与最大翻页深度的灵活配置，将零散职位页沉淀为<cyan>结构化职位记录</cyan>并去重入库。',

      // 左栏配置面板
      palette: {
        title: '可配置参数 · Control Palette',
        nodes: [
          { id: 'city', label: '目标城市', en: 'City', icon: '📍' },
          { id: 'category', label: '岗位分类', en: 'Category', icon: '🧭' },
          { id: 'keyword', label: '多关键字队列', en: 'Keywords', icon: '🔁' },
        ],
      },

      // 中栏采集流程
      canvas: {
        title: '采集流水线 · Crawl Pipeline',
        cases: [
          {
            id: 'case1',
            label: '组装 Case 1: 反爬与稳健性',
            nodes: [
              { id: 'stealth', label: '隐藏自动化特征', type: 'router' },
              { id: 'dialog', label: '登录弹窗自动关闭', type: 'approval' },
              { id: 'scroll', label: '滚动加载与翻页等待', type: 'auth' },
            ],
          },
          {
            id: 'case2',
            label: '组装 Case 2: 结构化抽取',
            nodes: [
              { id: 'salary', label: '薪资/薪级正则解析', type: 'form' },
              { id: 'company', label: '公司画像抽取', type: 'submit' },
            ],
          },
        ],
      },

      // 右栏数据监视器
      inspector: {
        title: '结构化模型 · Job Schema',
        case1Json: {
          table: 'spider_db.job_info',
          dimensions: ['job_name', 'job_area', 'salary_range', 'salary_type'],
          company: ['job_industry', 'job_finance', 'job_scale'],
          requirements: ['job_experience', 'job_education', 'job_tag_list'],
          dedupKeys: ['job_id', '(job_name, job_company, job_area)'],
          antiCrawl: 'excludeSwitches + navigator.webdriver = undefined',
        },
        case2Json: {
          pipeline: 'spider → MySQL / Flask:5005 → weekly CSV → data.js',
          fieldCount: 21,
          archive: 'jobdata/YYYY-MM/week_WW.csv',
          charts: ['salary', 'geo', 'finance', 'scale', 'taxonomy', 'welfare'],
        },
      },
    },

    // Part 2: 数据分析看板
    part2: {
      sectionTag: 'SEGMENT 2 // ANALYTICS DASHBOARD',
      title: '多维数据分析看板',
      subtitle: 'ECharts 交叉分析的市场情报大屏',

      distillation: {
        title: '数据清洗与薪资归一化',
        desc: '解析"K / 薪 / 时 / 日 / 月"等异构薪资口径，统一折算为月薪 K 值；按公司与岗位去重剔除重复记录，过滤实习等杂讯，沉淀为可交叉统计的<emerald>干净分析底座</emerald>，支撑后续所有图表指标。',
      },

      recommendation: {
        title: '多维交叉分析洞察',
        desc: '以<emerald>ECharts</emerald>搭建市场大屏：大盘薪资直方图、公司规模薪资箱线图、行政区+子商圈嵌套玫瑰图、融资阶段环图，以及"B端/数据/AI"等细分赛道的需求量与均薪双轴对比，将招聘市场压缩成一张<emerald>可交互的情报地图</emerald>。',
      },

      // 原始杂乱状态（模拟）
      rawText:
        '"AI产品经理 杭州·滨江区·长河 MOODY 30-40K·12薪 C轮 100-499人 零食下午茶 五险一金..." 同一岗位在多个关键字下重复出现；薪资同时存在"200元/天"与"30-40K·14薪"等异构口径；大量职位卡片缺少融资阶段与福利标签，无法直接横向比较...',

      // 梳理/蒸馏结果（对应三大体验亮点）
      distilledFields: [
        {
          id: 'summary',
          label: '状态聚类聚合',
          en: 'Clustered Info',
          value: '将重复与异构数据统一收拢为：「岗位总数 1,234」「薪资中位数 22K」「高频集散地: 余杭区」三个清晰的市场指标。',
        },
        {
          id: 'timeline',
          label: '区域热度下钻',
          en: 'Drilldown',
          value: '行政区环图 → 子商圈玫瑰图逐级下钻，从"余杭区 89 岗 / 24.3K"细看到"仓前 31 岗"，区域薪酬差异一目了然。',
        },
        {
          id: 'clues',
          label: '赛道双轴对比',
          en: 'Dual Axis',
          value: '按岗位名与标签自动归类"B端/数据/AI"等细分方向，柱状展示需求量、折线对比均薪，高薪赛道秒级识别。',
        },
      ],

      // 亮点展示卡片
      similarCases: [
        {
          id: 'feature-spectrum',
          title: '01 · 薪资极化分布',
          similarity: 'Spectrum',
          desc: '大盘薪资 6 档直方图，峰值桶琥珀色高亮，一键过滤实习/兼职口径杂讯。',
          disposition: '秒懂岗位薪资区间分布，告别逐条翻阅。',
        },
        {
          id: 'feature-scale',
          title: '02 · 规模倒挂箱线图',
          similarity: 'Boxplot',
          desc: '按公司规模（0-20人 ~ 万人以上）计算薪资五数概括，剔除离群点后直观看方差与中位数。',
          disposition: '揭示"小公司未必低薪、大厂未必高薪"的真实倒挂。',
        },
        {
          id: 'feature-taxonomy',
          title: '03 · 黄金赛道双轴',
          similarity: 'Taxonomy',
          desc: '岗位名 + 标签关键词自动归类细分方向，需求量与平均薪资双轴联动对比。',
          disposition: '数据/AI/企服等赛道热度与溢价一屏掌握。',
        },
      ],

      // 按钮文案
      buttons: {
        execute: '体验数据看板渲染',
        edit: '切换市场/个人视角',
        simulateTimeout: '过滤实习岗位',
        retry: '重置 / Reset',
        ignore: '关闭 / Close',
      },

      // 错误/特殊标签
      errorTag: 'LIVE_FEED_ACTIVE',
    },
  },

  // 04. 结果 (RESULTS)
  results: {
    sectionTag: '04 / RESULTS',
    title: '结果',
    metric: {
      tag: 'DATA PIPELINE // 采集与洞察效率',
      numberValue: 7,
      numberPrefix: '',
      numberSuffix: '类图表',
      headline: '一键跑数，7 类图表直出市场洞察',
      desc: '从手动逐页翻看职位卡片，进化为一键跑数、看板直达：多关键字循环抓取 + 自动翻页 + 入库去重，让<cyan>结构化数据规模与洞察效率大幅提升</cyan>。',
      subtag: 'ONE-CLICK CRAWL → INSTANT INSIGHT',
    },
    methodology: {
      tag: 'METHODOLOGY // 工程与设计沉淀',
      title: '工程与设计沉淀',
      desc: '验证了"<b>工程化采集（Python + Selenium）</b> + <b>可视化叙事（ECharts）</b>"是打通招聘数据从"能拿到"到"看得懂"的最佳解法：以参数化与反爬健壮性保证数据质量，以交叉图表把市场复杂度压缩成直觉。',
      subtag: 'ROBUST CRAWLING + DATA NARRATIVE = CLEAR MARKET VIEW',
    },
    summary: {
      title: '采集引擎 × 数据叙事',
      desc: '以<b>参数化爬虫</b>沉淀结构化职位数据，以<b>ECharts 多维看板</b>呈现薪资、区域与赛道洞察。',
    },
  },
};
