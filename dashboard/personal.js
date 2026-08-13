(function() {
    // --- THEME CONSTANTS (Warm Synthesis) ---
    const PRIMARY_TEXT = '#2A2522';
    const MUTED_TEXT = '#736b63';
    const ACCENT_AMBER = '#d88922';
    const ACCENT_CORAL = '#E07A5F';
    const ACCENT_MINT = '#81B29A';
    const OCHRE = '#Cda361';
    const TERRACOTTA = '#A54F3F';

    // ECharts Base Options for Personal View
    const personalChartBaseOptions = {
        backgroundColor: 'transparent',
        textStyle: { fontFamily: "'Inter', sans-serif", color: MUTED_TEXT },
        tooltip: {
            backgroundColor: 'rgba(255, 255, 255, 0.95)',
            borderColor: 'rgba(0,0,0,0.05)',
            borderWidth: 1,
            padding: [12, 16],
            textStyle: { color: PRIMARY_TEXT, fontSize: 13, fontWeight: 500 },
            borderRadius: 8,
            boxShadow: '0 8px 24px rgba(180, 150, 100, 0.15)'
        },
        grid: { top: 40, right: 30, bottom: 40, left: 50 }
    };

    // State Variables
    let currentDimension = 'day'; // 'day', 'week'
    let personalCharts = [];
    let filteredPersonalData = [];
    let parsedResumeText = "";

    // VSM Competency Dimensions Matrix
    const competencyDimensions = {
        ai: {
            name: "AI & LLM 实践能力",
            terms: ["ai", "aigc", "rag", "dify", "agent", "llm", "prompt", "大模型", "提示词", "知识库", "工作流", "向量化"]
        },
        saas: {
            name: "B端产品与系统架构",
            terms: ["saas", "b端", "tob", "后台", "中台", "重构", "权限", "审批", "多维表单", "配置", "底盘"]
        },
        data: {
            name: "数据分析与策略算法",
            terms: ["数据分析", "sql", "bi", "推荐系统", "算法", "协同过滤", "状态机", "风控", "高并发", "熔断", "预扣减"]
        },
        growth: {
            name: "C端增长与商业出海",
            terms: ["c端", "toc", "用户运营", "商业化", "增长", "流量分发", "出海", "seo", "广告投放", "私域"]
        },
        basics: {
            name: "PM 核心基本功",
            terms: ["prd", "原型", "axure", "figma", "竞品分析", "需求分析", "跨部门", "交付"]
        }
    };

    // Concrete Polishing Recommendations with Action Verbs and Contexts
    const polishingTips = {
        data: {
            title: "数据分析与策略算法",
            original: "提升券码、推荐等策略表现",
            diagnostic: "当前成功投递岗位在【数据驱动与风控拦截】维度上要求极高。市场普遍关注“高并发风控底盘”、“状态机防刷锁”以及“算法分发模型”，简单的‘提升策略’无法体现业务深度。",
            recommendation: "主导自营商城券码互斥与流量分发策略，**重构营销风控底座（引入 Redis 预扣减与最低折扣率熔断状态机）**，大促高并发场景下从配置端到后端双层防御黑产套利，全站点击率拉升且自营商城复购率提升至 **23%**。"
        },
        saas: {
            title: "B端产品与系统架构",
            original: "主导过多次 0-1 产品设计与老系统再设计",
            diagnostic: "SaaS 核心招聘方高度敏感于“定制开发高损耗”痛点。职位描述中高频要求“架构标准化、逆向重构、通用业务底座（权限、审批、多维表单）的抽象设计能力”。",
            recommendation: "主导多次 ToB 标准化产品线 0-1 设计与逆向架构重构，**梳理并重新划定产品业务流边界**。剔除冗余业务，**抽象出权限、审批、多维表单等通用组件底座**，推动业务线完成‘平台化’转型，使后续定制开发成本降低 **40%**。"
        },
        ai: {
            title: "AI & LLM 实践能力",
            original: "熟练使用 Dify等工具进行可视化编排",
            diagnostic: "大模型（LLM）与工作流编排是您的核心壁垒。市场在招聘 AI PM 时，更看重对于“LLM 幻觉控制”、“双 Persona 协同路由”、“向量化召回率（RAG）”等可度量的工程设计落地。",
            recommendation: "深度实践大模型工作流，基于 Dify 等工具构建 **‘产品经理 + 架构师’双 Persona 协同与意图识别路由分发机制**，深度结合 RAG 本地知识库匹配，降低模型幻觉，大幅提升 PRD 生成的准确率与可用度。"
        }
    };

    // Tab switching logic
    function switchTab(tabId) {
        const marketBtn = document.getElementById('btn-tab-market');
        const personalBtn = document.getElementById('btn-tab-personal');
        const marketView = document.getElementById('tab-market-view');
        const personalView = document.getElementById('tab-personal-view');

        if (!marketBtn || !personalBtn || !marketView || !personalView) return;

        if (tabId === 'market') {
            marketBtn.classList.add('active');
            personalBtn.classList.remove('active');
            marketView.classList.add('active');
            personalView.classList.remove('active');
        } else if (tabId === 'personal') {
            personalBtn.classList.add('active');
            marketBtn.classList.remove('active');
            personalView.classList.add('active');
            marketView.classList.remove('active');

            // Always render (or re-render) the personal dashboard when tab is clicked
            initPersonalDashboard();
        }

        // Always resize market charts as well
        if (typeof charts !== 'undefined' && Array.isArray(charts)) {
            setTimeout(() => {
                charts.forEach(c => { try { c.resize(); } catch(e) {} });
            }, 80);
        }
    }

    // Load resume through Flask API server with local relative fallback
    async function loadResume() {
        const statusEl = document.getElementById('personal-val-match-status');
        const suggestionList = document.getElementById('resume-suggestions-list');
        
        if (!statusEl || !suggestionList) return;

        statusEl.innerText = "载入简历中...";

        try {
            let response = await fetch('http://localhost:5005/api/get_resume');
            if (!response.ok) {
                response = await fetch('resume.md');
            }
            if (!response.ok) throw new Error("Fetch failed");
            
            const data = await response.json();
            parsedResumeText = data.content || "";
            statusEl.innerText = "就绪";
            statusEl.style.color = ACCENT_MINT;
            runResumeAudit();
        } catch (err) {
            console.warn("Could not fetch resume from Flask, trying direct text load from resume.md...", err);
            try {
                let relativeResp = await fetch('resume.md');
                if (relativeResp.ok) {
                    parsedResumeText = await relativeResp.text();
                    statusEl.innerText = "就绪";
                    statusEl.style.color = ACCENT_MINT;
                    runResumeAudit();
                } else {
                    throw new Error("Relative fetch failed");
                }
            } catch (relErr) {
                statusEl.innerText = "未载入简历";
                statusEl.style.color = TERRACOTTA;
                suggestionList.innerHTML = `<li style="margin-bottom: 8px; line-height: 1.4; color: var(--text-muted)">
                    无法自动加载 <span style="font-family: var(--font-sans); color: var(--terracotta);">resume.md</span>。<br>
                    <span style="font-size: 0.8rem; color: var(--text-muted)">提示：请确保 Python Flask 服务运行于 5005 端口，或通过本地 Web 服务器（如 python -m http.server）访问此页面。</span>
                </li>`;
            }
        }
    }

    // Simple Markdown parsing function for preview
    function parseMarkdownToHtml(md) {
        let html = md;
        
        // Headers
        html = html.replace(/^#\s+(.*)$/gm, '<h2 style="font-family: var(--font-serif); font-size: 1.1rem; color: var(--terracotta); border-bottom: 1px solid rgba(205,163,97,0.2); padding-bottom: 4px; margin: 10px 0 6px 0;">$1</h2>');
        html = html.replace(/^##\s+(.*)$/gm, '<h3 style="font-family: var(--font-serif); font-size: 0.95rem; color: var(--text-dark); margin: 10px 0 4px 0;">$1</h3>');
        html = html.replace(/^###\s+(.*)$/gm, '<h4 style="font-family: var(--font-sans); font-size: 0.85rem; font-weight: 600; color: var(--accent-amber); margin: 6px 0 2px 0;">$1</h4>');
        
        // Bold / Italics
        html = html.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');
        html = html.replace(/\*(.*?)\*/g, '<em>$1</em>');
        
        // Unordered lists
        html = html.replace(/^\s*[\-\*]\s+(.*)$/gm, '<div style="margin-left: 8px; text-indent: -8px; margin-bottom: 4px; font-size: 0.75rem;">• $1</div>');
        
        // Paragraph linebreaks
        html = html.replace(/\n/g, '<br>');
        
        return html;
    }

    // Vector Calculation Helpers
    function computeVector(text) {
        const vector = {};
        const lowerText = text.toLowerCase();
        
        Object.entries(competencyDimensions).forEach(([key, dim]) => {
            let count = 0;
            dim.terms.forEach(term => {
                const escapedTerm = term.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
                const regex = new RegExp(escapedTerm, 'gi');
                const matches = lowerText.match(regex);
                if (matches) {
                    count += matches.length;
                }
            });
            vector[key] = count;
        });
        return vector;
    }

    function normalizeVector(vector) {
        let sumSq = 0;
        Object.values(vector).forEach(val => { sumSq += val * val; });
        const mag = Math.sqrt(sumSq) || 1;
        
        const normalized = {};
        Object.entries(vector).forEach(([key, val]) => {
            normalized[key] = val / mag;
        });
        return normalized;
    }

    function cosineSimilarity(v1, v2) {
        let dotProduct = 0;
        Object.keys(v1).forEach(key => {
            dotProduct += (v1[key] || 0) * (v2[key] || 0);
        });
        return dotProduct;
    }

    // Dynamic Annotation click trigger
    function showPolishingTip(element, dimension) {
        document.querySelectorAll('.resume-highlight').forEach(el => el.classList.remove('active'));
        if (element) element.classList.add('active');

        const card = document.getElementById('resume-polishing-card');
        if (!card) return;

        const tipData = polishingTips[dimension];
        if (!tipData) return;

        // Revamp right side note as interactive workbench card
        card.style.background = '#fff';
        card.style.border = '1px solid rgba(205,163,97,0.3)';
        card.style.textAlign = 'left';
        card.style.alignItems = 'stretch';
        card.style.justifyContent = 'flex-start';
        card.style.padding = '14px';

        card.innerHTML = `
            <div style="font-family: 'Noto Serif SC', serif; font-size: 0.9rem; font-weight: 700; color: var(--terracotta); border-bottom: 2px solid rgba(205,163,97,0.2); padding-bottom: 6px; margin-bottom: 10px; display: flex; align-items: center; gap: 6px;">
                <span>💡</span> 语义批注诊断工作台 [${tipData.title}]
            </div>
            <div style="margin-bottom: 8px;">
                <strong style="color: var(--text-muted); font-size: 0.72rem; display: block; margin-bottom: 2px;">🔴 当前写法：</strong>
                <div style="background: rgba(0,0,0,0.02); border-left: 3px solid var(--text-muted); padding: 4px 8px; font-family: var(--font-sans); color: var(--text-dark); font-size: 0.78rem; font-style: italic;">
                    "${tipData.original}"
                </div>
            </div>
            <div style="margin-bottom: 10px;">
                <strong style="color: var(--accent-amber); font-size: 0.72rem; display: block; margin-bottom: 2px;">🟡 市场需求诊断：</strong>
                <div style="color: #665f57; font-size: 0.75rem; line-height: 1.45;">
                    ${tipData.diagnostic}
                </div>
            </div>
            <div style="flex-grow: 1; display: flex; flex-direction: column;">
                <strong style="color: var(--sage); font-size: 0.72rem; display: block; margin-bottom: 2px;">🟢 推荐量化润色建议（可点选替换）：</strong>
                <div style="background: rgba(129,178,154,0.08); border-left: 3px solid var(--accent-mint); padding: 8px; border-radius: 0 4px 4px 0; font-family: var(--font-sans); color: var(--text-dark); font-size: 0.78rem; font-weight: 500; line-height: 1.5; border: 1px dashed rgba(129,178,154,0.2); border-left: 3px solid var(--accent-mint); overflow-y: auto; flex-grow: 1;">
                    ${tipData.recommendation}
                </div>
            </div>
        `;
    }
    window.showPolishingTip = showPolishingTip;

    // VSM Analysis & Annotated Resume Renderer
    function runResumeAudit() {
        const matchValEl = document.getElementById('personal-val-match');
        const matchedStatusEl = document.getElementById('personal-val-match-status');
        const insightsWrapper = document.querySelector('.resume-insights-wrapper');

        if (!matchValEl || !insightsWrapper || !parsedResumeText) return;

        // 1. Compute market vector from success applied JDs
        const successJobs = filteredPersonalData.filter(j => j.deliver_status === 'success');
        if (successJobs.length === 0) {
            matchValEl.innerText = "0%";
            if (matchedStatusEl) matchedStatusEl.innerText = "无投递成功岗位数据";
            insightsWrapper.innerHTML = `<div style="text-align: center; color: var(--text-muted); padding: 4rem 0;">
                筛选范围内暂无投递成功岗位，无法提取市场高频需求画像。
            </div>`;
            return;
        }

        // Aggregate success JDs text
        let mergedJdsText = "";
        successJobs.forEach(job => {
            mergedJdsText += " " + (job.post_description || "") + " " + (job.job_name || "") + " " + (job.job_tag_list || "");
        });

        // Compute VSM Vectors
        const marketRawVector = computeVector(mergedJdsText);
        const resumeRawVector = computeVector(parsedResumeText);

        const marketVector = normalizeVector(marketRawVector);
        const resumeVector = normalizeVector(resumeRawVector);

        // Cosine Similarity Score
        const similarityScore = cosineSimilarity(marketVector, resumeVector);
        const matchPct = Math.round(similarityScore * 100);

        matchValEl.innerText = `${matchPct}%`;

        // Update top-level status
        if (matchedStatusEl) {
            if (matchPct >= 75) {
                matchedStatusEl.innerText = "语义高度契合 (Strong)";
                matchedStatusEl.style.color = ACCENT_MINT;
            } else if (matchPct >= 45) {
                matchedStatusEl.innerText = "基本语义契合 (Fair)";
                matchedStatusEl.style.color = ACCENT_AMBER;
            } else {
                matchedStatusEl.innerText = "匹配度低需润色 (Weak)";
                matchedStatusEl.style.color = TERRACOTTA;
            }
        }

        // 2. Parse Markdown resume and inject span anchors
        let resumeHtml = parseMarkdownToHtml(parsedResumeText);

        // Wrap anchor sentences with highlight tags
        resumeHtml = resumeHtml.replace(
            '提升券码、推荐等策略表现',
            '<span class="resume-highlight" onclick="showPolishingTip(this, \'data\')">提升券码、推荐等策略表现</span>'
        );
        resumeHtml = resumeHtml.replace(
            '主导过多次 0-1 产品设计与老系统再设计',
            '<span class="resume-highlight" onclick="showPolishingTip(this, \'saas\')">主导过多次 0-1 产品设计与老系统再设计</span>'
        );
        resumeHtml = resumeHtml.replace(
            'Dify等工具进行可视化编排',
            '<span class="resume-highlight" onclick="showPolishingTip(this, \'ai\')">Dify等工具进行可视化编排</span>'
        );

        // Overwrite outer wrapping container as split layout
        insightsWrapper.innerHTML = `
            <div class="resume-dual-pane" style="display: flex; gap: 1rem; height: 100%; overflow: hidden; margin-top: 0.5rem; flex-grow: 1;">
                <!-- Left: Interactive Annotated Resume Preview -->
                <div class="resume-preview-pane" style="flex: 1.15; overflow-y: auto; padding-right: 8px; border-right: 1px solid rgba(205,163,97,0.15); font-size: 0.78rem; line-height: 1.55; color: var(--text-dark); user-select: text; border-radius: 4px; padding-left: 2px;">
                    ${resumeHtml}
                </div>
                <!-- Right: Polishing interactive sticky note workbench -->
                <div id="resume-polishing-card" class="resume-polish-pane" style="flex: 0.85; display: flex; flex-direction: column; justify-content: center; align-items: center; background: rgba(205,163,97,0.04); border: 1px dashed rgba(205,163,97,0.3); border-radius: 8px; padding: 12px; font-size: 0.78rem; color: var(--text-muted); text-align: center; overflow-y: auto;">
                    <div style="font-size: 1.5rem; margin-bottom: 6px;">💡</div>
                    <div style="font-weight: 700; color: var(--text-dark); margin-bottom: 4px; font-family: 'Noto Serif SC', serif;">简历智能批注诊断</div>
                    <div style="font-size: 0.72rem; color: var(--text-muted); line-height: 1.45; padding: 0 4px;">
                        点击左侧简历中带有黄色虚线下划线的描述，即可在此工作台读取对应的「语义偏离分析」与「高管级润色文案」。
                    </div>
                </div>
            </div>
        `;
    }

    function formatDateToYMD(d) {
        if (!d || isNaN(d.getTime())) return '';
        const y = d.getFullYear();
        const m = String(d.getMonth() + 1).padStart(2, '0');
        const day = String(d.getDate()).padStart(2, '0');
        return `${y}-${m}-${day}`;
    }

    // Compute Date Window and Filter
    function processPersonalData() {
        if (typeof jobData === 'undefined' || !Array.isArray(jobData)) {
            filteredPersonalData = [];
            return;
        }

        const startInput = document.getElementById('start-date-input');
        const endInput = document.getElementById('end-date-input');

        // Extract clean, valid timestamps from jobData
        const validTimestamps = jobData.map(j => {
            if (!j || !j.create_time) return null;
            const str = String(j.create_time).trim().replace(/\//g, '-');
            const d = new Date(str + 'T00:00:00');
            const t = d.getTime();
            return isNaN(t) ? null : t;
        }).filter(t => t !== null && t > 0);

        // Set default 14 days range if date inputs are empty
        if (startInput && endInput && (!startInput.value || !endInput.value)) {
            let maxT = Date.now();
            if (validTimestamps.length > 0) {
                maxT = validTimestamps.reduce((max, v) => (v > max ? v : max), 0);
            }

            const maxDate = new Date(maxT);
            const minDate = new Date(maxT - 14 * 24 * 60 * 60 * 1000);

            if (!endInput.value) {
                endInput.value = formatDateToYMD(maxDate);
            }
            if (!startInput.value) {
                startInput.value = formatDateToYMD(minDate);
            }
        }

        const startVal = startInput?.value;
        const endVal = endInput?.value;

        let startTime = -Infinity;
        let endTime = Infinity;

        if (startVal) {
            const d = new Date(startVal + 'T00:00:00');
            if (!isNaN(d.getTime())) startTime = d.getTime();
        }
        if (endVal) {
            const d = new Date(endVal + 'T23:59:59');
            if (!isNaN(d.getTime())) endTime = d.getTime();
        }

        filteredPersonalData = jobData.filter(job => {
            if (!job || !job.create_time) return false;
            const str = String(job.create_time).trim().replace(/\//g, '-');
            const d = new Date(str + 'T12:00:00');
            const t = d.getTime();
            if (isNaN(t)) return true; // Keep record if date parsing fails
            return t >= startTime && t <= endTime;
        });
    }

    // Update Top Metrics Row
    function updatePersonalMetricsUI() {
        const totalEl = document.getElementById('personal-val-total');
        const rateEl = document.getElementById('personal-val-rate');
        const successEl = document.getElementById('personal-val-success-count');

        if (!totalEl || !rateEl || !successEl) return;

        const totalCount = filteredPersonalData.length;
        const successCount = filteredPersonalData.filter(j => j.deliver_status === 'success').length;
        const ratePct = totalCount > 0 ? Math.round((successCount / totalCount) * 100) : 0;

        totalEl.innerText = totalCount.toLocaleString();
        rateEl.innerText = `${ratePct}%`;
        successEl.innerText = `${successCount} 次成功投递`;
    }

    // ECharts 1: Funnel Chart
    function initFunnelChart() {
        const chart = echarts.init(document.getElementById('personal-chart-funnel'));
        const totalCount = filteredPersonalData.length;
        
        const filteredCount = filteredPersonalData.filter(j => j.deliver_status === 'warning').length;
        const successCount = filteredPersonalData.filter(j => j.deliver_status === 'success').length;
        
        const passedCount = totalCount - filteredCount;

        const funnelData = [
            { name: '1. 获取岗位数', value: totalCount },
            { name: '2. 初筛通过数', value: passedCount },
            { name: '3. 简历发送数', value: successCount }
        ];

        const option = {
            ...personalChartBaseOptions,
            tooltip: {
                trigger: 'item',
                formatter: '{b} : {c} 岗 ({d}%)'
            },
            color: [OCHRE, ACCENT_AMBER, TERRACOTTA],
            series: [
                {
                    name: '投递转化漏斗',
                    type: 'funnel',
                    left: '10%',
                    top: '15%',
                    bottom: '10%',
                    width: '80%',
                    min: 0,
                    max: totalCount || 100,
                    minSize: '0%',
                    maxSize: '100%',
                    sort: 'descending',
                    gap: 5,
                    label: {
                        show: true,
                        position: 'inside',
                        formatter: '{b}: {c}',
                        color: '#fff',
                        fontWeight: 600,
                        fontSize: 11
                    },
                    itemStyle: {
                        borderColor: '#fff',
                        borderWidth: 1
                    },
                    emphasis: {
                        label: {
                            fontSize: 14
                        }
                    },
                    data: funnelData
                }
            ]
        };

        chart.setOption(option);
        return chart;
    }

    // ECharts 2: Filter Attribution (Donut Chart)
    function initAttributionChart() {
        const chart = echarts.init(document.getElementById('personal-chart-attribution'));
        
        const warningJobs = filteredPersonalData.filter(j => j.deliver_status === 'warning');
        const reasonsMap = {};

        warningJobs.forEach(job => {
            let reason = job.filter_reason || '其他规则';
            if (reason.trim() === '') reason = '未指明原因';
            const category = reason.split(':')[0].trim();
            reasonsMap[category] = (reasonsMap[category] || 0) + 1;
        });

        const seriesData = Object.entries(reasonsMap)
            .map(([name, value]) => ({ name, value }))
            .sort((a, b) => b.value - a.value);

        const option = {
            ...personalChartBaseOptions,
            tooltip: {
                trigger: 'item',
                formatter: '{b} : {c} 次 ({d}%)'
            },
            color: [TERRACOTTA, ACCENT_AMBER, OCHRE, ACCENT_MINT, '#D4B895', '#e9d7c3'],
            legend: {
                orient: 'vertical',
                right: '5%',
                top: 'center',
                icon: 'circle',
                textStyle: { color: PRIMARY_TEXT, fontSize: 11 }
            },
            series: [
                {
                    name: '拦截归因',
                    type: 'pie',
                    radius: ['45%', '75%'],
                    center: ['38%', '50%'],
                    avoidLabelOverlap: false,
                    itemStyle: {
                        borderRadius: 4,
                        borderColor: '#fff',
                        borderWidth: 2
                    },
                    label: {
                        show: false
                    },
                    data: seriesData.length > 0 ? seriesData : [{ name: '无过滤记录', value: 0 }]
                }
            ]
        };

        chart.setOption(option);
        return chart;
    }

    // ECharts 3: Daily/Weekly Trend Line Chart
    function initTrendChart() {
        const chart = echarts.init(document.getElementById('personal-chart-trend'));

        const formatDateStr = (d) => {
            const y = d.getFullYear();
            const m = String(d.getMonth() + 1).padStart(2, '0');
            const r = String(d.getDate()).padStart(2, '0');
            return `${y}/${m}/${r}`;
        };

        const getWeekStr = (d) => {
            const target = new Date(d.valueOf());
            const dayNr = (d.getDay() + 6) % 7;
            target.setDate(target.getDate() - dayNr + 3);
            const firstThursday = target.valueOf();
            target.setMonth(0, 1);
            if (target.getDay() !== 4) {
                target.setMonth(0, 1 + ((4 - target.getDay()) + 7) % 7);
            }
            const weekNo = 1 + Math.ceil((firstThursday - target) / 604800000);
            return `${target.getFullYear()}-W${String(weekNo).padStart(2, '0')}`;
        };

        let dates = filteredPersonalData.map(j => new Date(j.create_time)).filter(d => !isNaN(d));
        if (dates.length === 0) {
            chart.setOption({
                ...personalChartBaseOptions,
                xAxis: { type: 'category', data: [] },
                yAxis: { type: 'value' },
                series: []
            });
            return chart;
        }

        dates.sort((a, b) => a - b);
        const minDate = new Date(dates[0]);
        const maxDate = new Date(dates[dates.length - 1]);

        const categories = [];
        const successData = [];
        const warningData = [];

        if (currentDimension === 'day') {
            let cur = new Date(minDate);
            while (cur <= maxDate) {
                const formatted = formatDateStr(cur);
                categories.push(formatted);
                successData.push(0);
                warningData.push(0);
                cur.setDate(cur.getDate() + 1);
            }

            filteredPersonalData.forEach(job => {
                const jobDateStr = formatDateStr(new Date(job.create_time));
                const idx = categories.indexOf(jobDateStr);
                if (idx !== -1) {
                    if (job.deliver_status === 'success') successData[idx]++;
                    else if (job.deliver_status === 'warning') warningData[idx]++;
                }
            });
        } else {
            let cur = new Date(minDate);
            cur.setDate(cur.getDate() - ((cur.getDay() + 6) % 7));

            while (cur <= maxDate) {
                const weekStr = getWeekStr(cur);
                if (!categories.includes(weekStr)) {
                    categories.push(weekStr);
                }
                cur.setDate(cur.getDate() + 7);
            }
            
            const maxWeekStr = getWeekStr(maxDate);
            if (!categories.includes(maxWeekStr)) {
                categories.push(maxWeekStr);
            }

            categories.forEach(() => {
                successData.push(0);
                warningData.push(0);
            });

            filteredPersonalData.forEach(job => {
                const jobWeekStr = getWeekStr(new Date(job.create_time));
                const idx = categories.indexOf(jobWeekStr);
                if (idx !== -1) {
                    if (job.deliver_status === 'success') successData[idx]++;
                    else if (job.deliver_status === 'warning') warningData[idx]++;
                }
            });
        }

        const option = {
            ...personalChartBaseOptions,
            legend: {
                data: ['成功投递', '被拦截'],
                top: 10,
                textStyle: { color: PRIMARY_TEXT }
            },
            xAxis: {
                type: 'category',
                data: categories,
                axisLine: { show: false },
                axisTick: { show: false },
                axisLabel: { color: MUTED_TEXT, fontSize: 10, rotate: categories.length > 15 ? 30 : 0 }
            },
            yAxis: {
                type: 'value',
                splitLine: { lineStyle: { type: 'dashed', color: 'rgba(0,0,0,0.05)' } },
                axisLabel: { color: MUTED_TEXT }
            },
            series: [
                {
                    name: '成功投递',
                    type: 'line',
                    data: successData,
                    smooth: true,
                    itemStyle: { color: ACCENT_MINT },
                    lineStyle: { width: 3 },
                    symbolSize: 6
                },
                {
                    name: '被拦截',
                    type: 'line',
                    data: warningData,
                    smooth: true,
                    itemStyle: { color: TERRACOTTA },
                    lineStyle: { width: 3, type: 'dashed' },
                    symbolSize: 6
                }
            ]
        };

        chart.setOption(option);
        return chart;
    }

    // ECharts 4: Experience Contrast Bar Chart
    function initContrastChart() {
        const chart = echarts.init(document.getElementById('personal-chart-contrast'));
        
        const expLabels = ['不限', '在校/应届', '1年以下', '1-3年', '3-5年', '5-10年', '10年以上'];
        const successCounts = expLabels.map(() => 0);
        const warningCounts = expLabels.map(() => 0);

        filteredPersonalData.forEach(job => {
            let exp = job.job_experience || '不限';
            if (exp.includes('应届生') || exp.includes('在校')) exp = '在校/应届';
            else if (exp.includes('1年以下')) exp = '1年以下';
            else if (exp.includes('1-3年') || exp.includes('1-3')) exp = '1-3年';
            else if (exp.includes('3-5年') || exp.includes('3-5')) exp = '3-5年';
            else if (exp.includes('5-10年') || exp.includes('5-10')) exp = '5-10年';
            else if (exp.includes('10年以上') || exp.includes('10年')) exp = '10年以上';
            else exp = '不限';

            const idx = expLabels.indexOf(exp);
            if (idx !== -1) {
                if (job.deliver_status === 'success') successCounts[idx]++;
                else if (job.deliver_status === 'warning') warningCounts[idx]++;
            }
        });

        const option = {
            ...personalChartBaseOptions,
            legend: {
                data: ['投递成功', '规则拦截'],
                top: 10,
                textStyle: { color: PRIMARY_TEXT }
            },
            xAxis: {
                type: 'category',
                data: expLabels,
                axisLine: { show: false },
                axisTick: { show: false },
                axisLabel: { color: MUTED_TEXT }
            },
            yAxis: {
                type: 'value',
                splitLine: { lineStyle: { type: 'dashed', color: 'rgba(0,0,0,0.05)' } },
                axisLabel: { color: MUTED_TEXT }
            },
            series: [
                {
                    name: '投递成功',
                    type: 'bar',
                    data: successCounts,
                    itemStyle: { color: ACCENT_MINT, borderRadius: [4, 4, 0, 0] },
                    barWidth: '25%'
                },
                {
                    name: '规则拦截',
                    type: 'bar',
                    data: warningCounts,
                    itemStyle: { color: TERRACOTTA, borderRadius: [4, 4, 0, 0] },
                    barWidth: '25%'
                }
            ]
        };

        chart.setOption(option);
        return chart;
    }

    // Render False Positives Table with conditional JD back-check button
    function renderFalsePositivesTable() {
        const tbody = document.getElementById('false-positives-list');
        if (!tbody) return;

        const potentialFP = filteredPersonalData.filter(job => {
            if (job.deliver_status !== 'warning') return false;
            
            const isPM = /(产品|pm|product|智能体|agent|模型)/i.test(job.job_name || "");
            const isDuplicate = /(重复|相同公司)/.test(job.filter_reason || "");
            
            return isPM && !isDuplicate;
        });

        potentialFP.sort((a, b) => {
            const scoreA = a.ai_score !== null ? parseInt(a.ai_score) : -1;
            const scoreB = b.ai_score !== null ? parseInt(b.ai_score) : -1;
            return scoreB - scoreA;
        });

        tbody.innerHTML = "";
        
        if (potentialFP.length === 0) {
            tbody.innerHTML = `<tr>
                <td colspan="4" style="text-align: center; color: var(--text-muted); padding: 4rem 0;">
                    🟢 筛选范围内未发现潜在的误拦截良性产品经理岗位。
                </td>
            </tr>`;
            return;
        }

        potentialFP.slice(0, 15).forEach(job => {
            const tr = document.createElement('tr');
            
            // Render row - hide details button if JD description is empty
            const hasJd = job.post_description && job.post_description.trim() !== '';
            
            tr.innerHTML = `
                <td style="padding: 10px 12px; font-weight: 500;">${job.job_company || '未知公司'}</td>
                <td style="padding: 10px 12px;">
                    <div style="font-weight: 600; color: var(--text-dark);">${job.job_name}</div>
                    <div style="font-size: 0.75rem; color: var(--text-muted);">${job.salary_range} ｜ ${job.job_experience} ｜ ${job.job_education}</div>
                </td>
                <td style="padding: 10px 12px; color: var(--terracotta); font-weight: 500;">
                    ${job.filter_reason || '未知理由'}${job.filter_detail ? `<div style="font-size: 0.75rem; color: var(--text-muted); margin-top: 2px;">${job.filter_detail}</div>` : ''}
                    ${job.ai_score ? `<span style="display:inline-block; padding: 1px 6px; font-size: 0.7rem; border-radius: 4px; background: rgba(216,137,34,0.1); color: var(--accent-amber); margin-left: 6px;">AI: ${job.ai_score}分</span>` : ''}
                </td>
                <td style="padding: 10px 12px; text-align: center;">
                    ${hasJd ? 
                        `<button class="museum-btn-small" onclick="viewJdDetail('${job.job_id}')">回溯 JD</button>` : 
                        `<span style="color: var(--text-muted); font-size: 0.75rem;">无 JD 详情</span>`
                    }
                </td>
            `;
            tbody.appendChild(tr);
        });
    }

    // JD Detail Modal Controller
    function viewJdDetail(jobId) {
        if (typeof jobData === 'undefined') return;
        const job = jobData.find(j => j.job_id === jobId);
        if (!job) return;

        const modalTitle = document.getElementById('modal-title');
        const modalContent = document.getElementById('modal-content');
        const modalOverlay = document.getElementById('jd-modal');

        if (!modalTitle || !modalContent || !modalOverlay) return;

        modalTitle.innerText = `${job.job_company} - ${job.job_name}`;
        
        let detailHtml = `
            <div style="margin-bottom: 1.2rem; display: flex; gap: 0.8rem; flex-wrap: wrap;">
                <span style="background: rgba(216, 137, 34, 0.1); color: var(--accent-amber); padding: 4px 10px; border-radius: 4px; font-size: 0.8rem; font-weight: 600;">薪资: ${job.salary_range} (${job.salary_type || '12薪'})</span>
                <span style="background: rgba(117, 138, 122, 0.1); color: var(--sage); padding: 4px 10px; border-radius: 4px; font-size: 0.8rem; font-weight: 600;">要求: ${job.job_experience} / ${job.job_education}</span>
                <span style="background: rgba(205, 163, 97, 0.1); color: var(--ochre); padding: 4px 10px; border-radius: 4px; font-size: 0.8rem; font-weight: 600;">地区: ${job.job_area}</span>
            </div>
            <div style="margin-bottom: 1.2rem; background: rgba(165, 79, 63, 0.05); border-left: 4px solid var(--terracotta); padding: 10px 15px; border-radius: 0 4px 4px 0;">
                <strong>安全拦截说明：</strong><br>
                <span style="font-size: 0.85rem; color: var(--text-dark);">规则类别：<strong style="color: var(--terracotta);">${job.filter_reason || '未知类别'}</strong></span>
                ${job.filter_detail ? `<div style="margin-top: 4px; font-size: 0.85rem; color: var(--text-dark);">拦截细节：<strong style="color: var(--terracotta);">${job.filter_detail}</strong></div>` : ''}
                ${job.ai_reason ? `<div style="margin-top: 4px; font-size: 0.8rem; color: var(--text-muted);">AI 评估意见: ${job.ai_reason}</div>` : ''}
            </div>
            <div style="border-top: 1px solid rgba(0,0,0,0.06); padding-top: 1.2rem;">
                <strong style="display: block; margin-bottom: 0.6rem; font-size: 0.95rem;">JD 原文职责描述：</strong>
                <div style="color: #4a443e; font-size: 0.85rem; white-space: pre-wrap; line-height: 1.7; font-family: var(--font-sans); max-height: 280px; overflow-y: auto; padding-right: 8px;">${job.post_description || '暂无详细工作描述内容。'}</div>
            </div>
        `;

        modalContent.innerHTML = detailHtml;
        modalOverlay.classList.add('active');
    }

    function closeJdModal() {
        const modalOverlay = document.getElementById('jd-modal');
        if (modalOverlay) {
            modalOverlay.classList.remove('active');
        }
    }

    // Main Personal Dashboard initializer
    function initPersonalDashboard() {
        personalCharts.forEach(c => { try { c.dispose(); } catch(e) {} });
        personalCharts = [];

        processPersonalData();
        updatePersonalMetricsUI();

        personalCharts.push(initFunnelChart());
        personalCharts.push(initAttributionChart());
        personalCharts.push(initTrendChart());
        personalCharts.push(initContrastChart());

        renderFalsePositivesTable();
        runResumeAudit();
    }

    // ── Bind all events immediately (scripts are at bottom of <body>; DOM is already parsed) ──
    (function bindPageEvents() {
        const startDateInput = document.getElementById('start-date-input');
        const endDateInput = document.getElementById('end-date-input');

        const triggerPersonalRender = () => {
            initPersonalDashboard();
        };

        if (startDateInput) {
            startDateInput.addEventListener('change', triggerPersonalRender);
        }
        if (endDateInput) {
            endDateInput.addEventListener('change', triggerPersonalRender);
        }

        const btnDay = document.getElementById('btn-dim-day');
        const btnWeek = document.getElementById('btn-dim-week');

        if (btnDay && btnWeek) {
            btnDay.addEventListener('click', () => {
                if (currentDimension === 'day') return;
                currentDimension = 'day';
                btnDay.classList.add('active');
                btnWeek.classList.remove('active');
                const idx = personalCharts.findIndex(c => c.getDom().id === 'personal-chart-trend');
                if (idx !== -1) {
                    personalCharts[idx].dispose();
                    personalCharts[idx] = initTrendChart();
                }
            });
            btnWeek.addEventListener('click', () => {
                if (currentDimension === 'week') return;
                currentDimension = 'week';
                btnWeek.classList.add('active');
                btnDay.classList.remove('active');
                const idx = personalCharts.findIndex(c => c.getDom().id === 'personal-chart-trend');
                if (idx !== -1) {
                    personalCharts[idx].dispose();
                    personalCharts[idx] = initTrendChart();
                }
            });
        }

        const modalOverlay = document.getElementById('jd-modal');
        if (modalOverlay) {
            modalOverlay.addEventListener('click', (e) => {
                if (e.target === modalOverlay) closeJdModal();
            });
        }

        // loadResume is async – safe to call immediately
        loadResume();
    })();

    // Explicitly export functions to global window for index.html inline click events
    window.switchTab = switchTab;
    window.viewJdDetail = viewJdDetail;
    window.closeJdModal = closeJdModal;
})();
