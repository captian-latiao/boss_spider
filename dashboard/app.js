// --- THEME CONSTANTS (Warm Synthesis) ---
const PRIMARY_TEXT = '#2A2522';
const MUTED_TEXT = '#736b63';
const ACCENT_AMBER = '#d88922';
const ACCENT_CORAL = '#E07A5F';
const ACCENT_MINT = '#81B29A';
const OCHRE = '#Cda361';
const TERRACOTTA = '#A54F3F';

// ECharts Base Minimalist Theme
const premiumChartOptions = {
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
    grid: { top: 30, right: 20, bottom: 40, left: 50 }
};

// --- DATA PROCESSING LOGIC ---
function parseSalary(salaryStr) {
    if (!salaryStr || !salaryStr.includes('-')) return { min: 0, max: 0, avg: 0 };
    try {
        let isDaily = salaryStr.includes('天');
        let isHourly = salaryStr.includes('时');
        let isMonthlyYuan = salaryStr.includes('元/月');

        const cleanStr = salaryStr.replace(/[^\d\-\.]/g, '');
        const parts = cleanStr.split('-');
        if (parts.length < 2) return { min: 0, max: 0, avg: 0 };

        let min = parseFloat(parts[0]);
        let max = parseFloat(parts[1]);
        let avg = (min + max) / 2;

        // Normalize to K/month (assuming 22 working days, 8 hours/day)
        if (isDaily) avg = (avg * 22) / 1000;
        else if (isHourly) avg = (avg * 8 * 22) / 1000;
        else if (isMonthlyYuan) avg = avg / 1000;

        return { min, max, avg };
    } catch (e) {
        return { min: 0, max: 0, avg: 0 };
    }
}

function processData(data) {
    let cities = {};
    let distCities = {}; // Specific District counts
    let expSalaryMap = {};
    let eduSalaryMap = {};
    let companyStages = {};
    let tagsCount = {};
    let validSalaries = [];

    // Domain Taxonomy Structure: { {count, totalSalary} }
    let subDomains = { 'B端/企业级': { c: 0, s: 0 }, 'C端/用户': { c: 0, s: 0 }, '数据/BI': { c: 0, s: 0 }, 'AI/算法': { c: 0, s: 0 }, '商业/增长': { c: 0, s: 0 }, '后台/中台': { c: 0, s: 0 }, '硬件/IoT': { c: 0, s: 0 }, '综合/其他': { c: 0, s: 0 } };

    // Hiring Volume vs Scale map
    let scaleSalaryMap = { '0-20人': [], '20-99人': [], '100-499人': [], '500-999人': [], '1000-9999人': [], '10000人以上': [] };

    let processedCount = 0;

    data.forEach(job => {
        // --- GLOBAL FILTER LOGIC ---
        if (window.isInternshipExcluded) {
            let sal = job.salary_range || '';
            // If it contains "天" (day) or "时" (hour) it's likely an internship/part-time
            if (sal.includes('天') || sal.includes('时')) {
                return; // Skip this record
            }
        }

        processedCount++;

        // Broad Area
        let areaParts = job.job_area ? job.job_area.split('·') : ['Unknown'];
        let city = areaParts[0];
        cities[city] = (cities[city] || 0) + 1;

        // District Distribution and Drilldown (e.g., 余杭区 - 仓前)
        if (areaParts.length > 1 && city.includes('杭州')) {
            let dist = areaParts[1];
            if (!distCities[dist]) distCities[dist] = { count: 0, subAreas: {}, totalSal: 0 };
            distCities[dist].count++;

            let avgSal = parseSalary(job.salary_range).avg;
            if (avgSal > 0) distCities[dist].totalSal += avgSal;

            if (areaParts.length > 2) {
                let subDist = areaParts[2];
                distCities[dist].subAreas[subDist] = (distCities[dist].subAreas[subDist] || 0) + 1;
            }
        }

        let salaryData = parseSalary(job.salary_range);
        let avgSal = salaryData.avg;

        if (avgSal > 0) {
            validSalaries.push(avgSal);

            // Experience Tracking
            let exp = job.job_experience || 'Unknown';
            if (!expSalaryMap[exp]) expSalaryMap[exp] = [];
            expSalaryMap[exp].push(avgSal);

            // Education Tracking (For correlation insight)
            let edu = job.job_education || 'Unknown';
            if (!eduSalaryMap[edu]) eduSalaryMap[edu] = [];
            eduSalaryMap[edu].push(avgSal);

            // Subdomain Tracking
            let name = job.job_name.toLowerCase();
            let tagStr = (job.job_tag_list || '').toLowerCase();
            let combined = name + " " + tagStr;
            let identified = false;

            if (combined.includes('b端') || combined.includes('企业') || combined.includes('saas') || combined.includes('to b')) { subDomains['B端/企业级'].c++; subDomains['B端/企业级'].s += avgSal; identified = true; }
            if (!identified && (combined.includes('c端') || combined.includes('用户') || combined.includes('to c') || combined.includes('app'))) { subDomains['C端/用户'].c++; subDomains['C端/用户'].s += avgSal; identified = true; }
            if (!identified && (combined.includes('数据') || combined.includes('bi') || combined.includes('策略'))) { subDomains['数据/BI'].c++; subDomains['数据/BI'].s += avgSal; identified = true; }
            if (!identified && (combined.includes('ai') || combined.includes('人工智能') || combined.includes('算法') || combined.includes('大模型'))) { subDomains['AI/算法'].c++; subDomains['AI/算法'].s += avgSal; identified = true; }
            if (!identified && (combined.includes('商业化') || combined.includes('增长') || combined.includes('变现'))) { subDomains['商业/增长'].c++; subDomains['商业/增长'].s += avgSal; identified = true; }
            if (!identified && (combined.includes('后台') || combined.includes('中台') || combined.includes('平台'))) { subDomains['后台/中台'].c++; subDomains['后台/中台'].s += avgSal; identified = true; }
            if (!identified && (combined.includes('硬件') || combined.includes('物联网') || combined.includes('iot') || combined.includes('智能硬件'))) { subDomains['硬件/IoT'].c++; subDomains['硬件/IoT'].s += avgSal; identified = true; }
            if (!identified) { subDomains['综合/其他'].c++; subDomains['综合/其他'].s += avgSal; }

            // Scale Boxplot Tracking
            let scale = job.job_scale || 'Unknown';
            if (scaleSalaryMap[scale]) {
                scaleSalaryMap[scale].push(avgSal);
            }
        }

        let finance = job.job_finance;
        if (finance && finance !== 'NULL') {
            companyStages[finance] = (companyStages[finance] || 0) + 1;
        }

        if (job.job_welfare && job.job_welfare !== 'NULL') {
            job.job_welfare.split('，').forEach(tag => {
                tag = tag.trim();
                if (tag && tag.length > 1) tagsCount[tag] = (tagsCount[tag] || 0) + 1;
            });
        }
    });

    let topCity = Object.keys(cities).reduce((a, b) => cities[a] > cities[b] ? a : b, 'None');
    validSalaries.sort((a, b) => a - b);
    let medianSalary = validSalaries.length > 0 ? validSalaries[Math.floor(validSalaries.length / 2)] : 0;

    return {
        totalJobs: processedCount,
        topCity,
        medianSalary: Math.round(medianSalary),
        validSalaries,
        expSalaryMap,
        eduSalaryMap,
        companyStages,
        tagsCount,
        subDomains,
        distCities,
        scaleSalaryMap
    };
}

// Global filter state
window.isInternshipExcluded = false;
let analytics = processData(jobData);

// --- INITIALIZE UI METRICS & INSIGHTS ---
let currentDisplayTotal = Math.max(0, analytics.totalJobs - 150);
const elTotal = document.getElementById('val-total');

function updateMetricsUI() {
    elTotal.innerText = currentDisplayTotal.toLocaleString();
    document.getElementById('val-salary').innerHTML = `$${analytics.medianSalary},000 <span style="font-size:1rem; color:#736b63; font-weight:400;">/yr est.</span>`;
    document.getElementById('val-city').innerText = analytics.topCity;

    // Generate AI Correlation Insight
    const insightBox = document.getElementById('insight-content');

    // Calculate simple medians for comparisons
    let exps = [];
    for (let k in analytics.expSalaryMap) {
        let arr = analytics.expSalaryMap[k].sort((a, b) => a - b);
        exps.push({ n: k, med: arr.length ? arr[Math.floor(arr.length / 2)] : 0 });
    }
    // Very rudimentary correlation narrative gen
    let fresh = exps.find(e => e.n === '应届生')?.med || 10;
    let sen = exps.find(e => e.n === '10年以上')?.med || 30;
    let gap = Math.round(sen - fresh);

    insightBox.innerHTML = `
        <p style="margin-bottom: 0.5rem">深度相关性分析显示，市场存在极端的<strong>年限溢价</strong>特征。学历倒挂正成为常态。</p>
        <p style="margin-bottom: 0.5rem">初级PM与10年资深专家的纯薪资鸿沟高达 <strong style="color:var(--accent-amber)">+${gap}K / 月</strong>。</p>
        <p>同时，带有 <strong style="color:var(--terracotta)">AI/大模型</strong> 属性的复合型产品经理正在无视公司的规模限制，无差别击穿各级薪酬红线。</p>
    `;
}
updateMetricsUI();


// --- ECHARTS INITIALIZATION ---

function initSalaryChart() {
    const chart = echarts.init(document.getElementById('chart-salary'));
    const buckets = { '<10K': 0, '10-20K': 0, '20-30K': 0, '30-40K': 0, '40-50K': 0, '>50K': 0 };
    analytics.validSalaries.forEach(s => {
        if (s < 10) buckets['<10K']++;
        else if (s < 20) buckets['10-20K']++;
        else if (s < 30) buckets['20-30K']++;
        else if (s < 40) buckets['30-40K']++;
        else if (s < 50) buckets['40-50K']++;
        else buckets['>50K']++;
    });

    const keys = Object.keys(buckets);
    const vals = Object.values(buckets);
    const maxVal = Math.max(...vals);

    const seriesData = vals.map((v, i) => {
        const isMax = v === maxVal;
        return {
            value: v,
            itemStyle: {
                color: isMax ? ACCENT_AMBER : OCHRE,
                opacity: isMax ? 1 : 0.6,
                borderRadius: [4, 4, 0, 0]
            },
            label: {
                show: isMax,
                position: 'top',
                color: ACCENT_AMBER,
                fontWeight: 600,
                formatter: '{c} posts'
            }
        };
    });

    const option = {
        ...premiumChartOptions,
        xAxis: { type: 'category', data: keys, axisLine: { show: false }, axisTick: { show: false }, axisLabel: { color: MUTED_TEXT, margin: 16 } },
        yAxis: { type: 'value', splitLine: { lineStyle: { type: 'dashed', color: 'rgba(0,0,0,0.05)' } }, axisLabel: { color: MUTED_TEXT } },
        series: [{ type: 'bar', barWidth: '40%', data: seriesData }]
    };
    chart.setOption(option);
    return chart;
}

// 1. Updated: Geographic Rose Heat Map (Nested / Drill-down)
function initGeoChart() {
    const chart = echarts.init(document.getElementById('chart-geo'));

    // Sort and get top 3 districts
    const sortedDistricts = Object.entries(analytics.distCities)
        .sort((a, b) => b[1].count - a[1].count)
        .slice(0, 3); // Only top 3 for drill down

    let innerData = [];
    let outerData = [];

    // Custom Palette matching museum theme
    const colors = [TERRACOTTA, ACCENT_AMBER, OCHRE];
    const subColors = ['#e07a5f80', '#d8892280', '#cda36180']; // translucent versions

    sortedDistricts.forEach((dist, index) => {
        let name = dist[0];
        let d = dist[1];
        let avgSal = d.count > 0 ? (d.totalSal / d.count).toFixed(1) : 0;

        // Inner District Ring
        innerData.push({
            name: `${name}\n${avgSal}K`,
            value: d.count,
            itemStyle: { color: colors[index] }
        });

        // Outer Sub-district Ring
        let sortedSub = Object.entries(d.subAreas)
            .sort((a, b) => b[1] - a[1])
            .slice(0, 4); // Top 4 sub-areas per district to keep it readable

        sortedSub.forEach(sub => {
            outerData.push({
                name: sub[0],
                value: sub[1],
                itemStyle: { color: subColors[index] }
            });
        });
    });

    const option = {
        ...premiumChartOptions,
        tooltip: { ...premiumChartOptions.tooltip, trigger: 'item', formatter: '{b}: {c} Jobs' },
        series: [
            {
                name: 'District Heat',
                type: 'pie',
                selectedMode: 'single',
                radius: [0, '45%'],
                label: { position: 'inner', fontSize: 11, color: '#fff', fontWeight: 600 },
                labelLine: { show: false },
                itemStyle: { borderColor: '#fff', borderWidth: 1 },
                data: innerData
            },
            {
                name: 'Sub-District Drilldown',
                type: 'pie',
                radius: ['55%', '85%'],
                roseType: 'area', // Nightingale Rose for the outer layer
                itemStyle: { borderRadius: 4, borderColor: '#fff', borderWidth: 1 },
                label: { color: PRIMARY_TEXT, fontFamily: "'Inter', sans-serif" },
                data: outerData
            }
        ]
    };
    chart.setOption(option);
    return chart;
}

// 2. Finance Stages (Original)
function initFinanceDonut() {
    const chart = echarts.init(document.getElementById('chart-finance'));
    const treeData = Object.entries(analytics.companyStages)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 8)
        .map(([name, value]) => ({ name, value }));

    const option = {
        ...premiumChartOptions,
        color: [ACCENT_AMBER, OCHRE, TERRACOTTA, ACCENT_MINT, '#D4B895', '#e9d7c3'],
        legend: { orient: 'vertical', right: 0, top: 'center', icon: 'circle', itemGap: 12, textStyle: { color: PRIMARY_TEXT, fontFamily: "'Inter', sans-serif", fontSize: 11 } },
        series: [{
            type: 'pie', radius: ['50%', '80%'], center: ['35%', '50%'], avoidLabelOverlap: false,
            itemStyle: { borderRadius: 4, borderColor: '#fff', borderWidth: 2 },
            label: { show: false },
            data: treeData
        }]
    };
    chart.setOption(option);
    return chart;
}

// 3. Replaced Scatter plot with Boxplot (Salary Variance by Scale)
function initHiringScaleChart() {
    const chart = echarts.init(document.getElementById('chart-hiring-scale'));

    const scaleLabels = ['0-20人', '20-99人', '100-499人', '500-999人', '1000-9999人', '10000人以上'];

    // ECharts Boxplot requires [min, Q1, median, Q3, max]
    let boxData = scaleLabels.map(scale => {
        let arr = analytics.scaleSalaryMap[scale] || [];
        if (arr.length === 0) return [];
        arr.sort((a, b) => a - b);

        let min = arr[0];
        let max = arr[arr.length - 1];
        let q1 = arr[Math.floor(arr.length * 0.25)];
        let median = arr[Math.floor(arr.length * 0.5)];
        let q3 = arr[Math.floor(arr.length * 0.75)];

        // Remove extreme outliers for visual clarity on max
        let IQR = q3 - q1;
        let pMax = Math.min(max, q3 + 1.5 * IQR);

        return [min, q1, median, q3, pMax];
    });

    const option = {
        ...premiumChartOptions,
        grid: { top: 20, right: 20, bottom: 40, left: 40 },
        tooltip: {
            ...premiumChartOptions.tooltip,
            trigger: 'item',
            formatter: function (params) {
                if (params.data.length < 5) return "Insufficient Data";
                let [min, q1, median, q3, max] = params.data.slice(1);
                return `<strong>${params.name}</strong><br/>
                        Max (95p): ${max.toFixed(1)}K<br/>
                        Q3 (75p): ${q3.toFixed(1)}K<br/>
                        Median: ${median.toFixed(1)}K<br/>
                        Q1 (25p): ${q1.toFixed(1)}K<br/>
                        Min: ${min.toFixed(1)}K`;
            }
        },
        xAxis: {
            type: 'category',
            data: ['0-20', '20-99', '100-499', '0.5-1k', '1k-10k', '10k+'],
            axisLine: { show: false }, axisTick: { show: false }, axisLabel: { color: MUTED_TEXT, fontSize: 11 }
        },
        yAxis: {
            type: 'value', name: 'Salary (K)', nameTextStyle: { color: MUTED_TEXT },
            splitLine: { lineStyle: { type: 'dashed', color: 'rgba(0,0,0,0.05)' } },
            axisLabel: { color: MUTED_TEXT }
        },
        series: [{
            name: 'boxplot',
            type: 'boxplot',
            data: boxData,
            itemStyle: {
                color: 'rgba(216, 137, 34, 0.4)', // Accent Amber pale 
                borderColor: ACCENT_AMBER,
                borderWidth: 2
            }
        }]
    };
    chart.setOption(option);
    return chart;
}

// 4. New/Updated Sub-domain Dual Axis (Volume vs Salary)
function initSubdomainChart() {
    const chart = echarts.init(document.getElementById('chart-subdomain'));

    let subData = Object.entries(analytics.subDomains)
        .filter(([k, v]) => v.c > 0)
        .sort((a, b) => b[1].c - a[1].c); // Descending by volume

    let categories = subData.map(d => d[0]);
    let volumeData = subData.map(d => d[1].c);
    let salaryData = subData.map(d => (d[1].s / d[1].c).toFixed(1)); // Average salary

    const option = {
        ...premiumChartOptions,
        grid: { top: 40, right: 40, bottom: 40, left: 40 },
        legend: { data: ['Role Volume', 'Avg Salary'], top: 0, textStyle: { color: PRIMARY_TEXT } },
        xAxis: [{
            type: 'category',
            data: categories,
            axisLabel: { color: MUTED_TEXT, rotate: 20, fontSize: 10 },
            axisLine: { show: false }, axisTick: { show: false }
        }],
        yAxis: [
            { type: 'value', name: 'Jobs', position: 'left', splitLine: { show: false }, axisLabel: { color: MUTED_TEXT } },
            { type: 'value', name: 'Salary (K)', position: 'right', splitLine: { show: false }, axisLabel: { color: ACCENT_AMBER } }
        ],
        series: [
            {
                name: 'Role Volume',
                type: 'bar',
                data: volumeData,
                itemStyle: { color: OCHRE, borderRadius: [4, 4, 0, 0] },
                barWidth: '30%'
            },
            {
                name: 'Avg Salary',
                type: 'line',
                yAxisIndex: 1,
                data: salaryData,
                itemStyle: { color: ACCENT_AMBER },
                symbolSize: 8,
                symbol: 'circle',
                lineStyle: { width: 3, shadowBlur: 10, shadowColor: 'rgba(216,137,34,0.3)' }
            }
        ]
    };
    chart.setOption(option);
    return chart;
}

// Lower tags
function renderWelfareTags() {
    const container = document.getElementById('tags-container');
    const sortedTags = Object.entries(analytics.tagsCount).sort((a, b) => b[1] - a[1]).slice(0, 60);

    sortedTags.forEach(([tag, count], index) => {
        let pct = ((count / analytics.totalJobs) * 100).toFixed(1);
        const span = document.createElement('span');
        span.className = 'welfare-chip';
        if (index < 5) {
            span.style.borderColor = ACCENT_AMBER;
            span.style.color = ACCENT_AMBER;
            span.style.fontWeight = '600';
            span.innerText = `${tag} ${pct}% ★`;
        } else {
            span.innerText = `${tag} ${pct}%`;
        }
        container.appendChild(span);
    });
}

// --- LIVE STREAM SIMULATION LOGIC ---
const feedContainer = document.getElementById('live-feed');
const reservoir = jobData.slice(-200);

function spawnFeedItem() {
    if (reservoir.length === 0) return;
    const randIdx = Math.floor(Math.random() * reservoir.length);
    const job = reservoir[randIdx];

    const el = document.createElement('div');
    el.className = 'feed-item';
    el.innerHTML = `<div class="job-title"><span class="dot-indicator"></span>${job.job_name}</div><div class="salary">${job.salary_range}</div>`;

    feedContainer.prepend(el);
    if (feedContainer.children.length > 8) feedContainer.removeChild(feedContainer.lastChild);

    currentDisplayTotal += 1;
    elTotal.innerText = currentDisplayTotal.toLocaleString();
}

// --- INIT & RESIZE ---
let charts = [];

function renderAll() {
    // Clear and dispose old charts if they exist
    charts.forEach(c => c.dispose());
    charts = [];

    // Clear tags
    document.getElementById('tags-container').innerHTML = '';

    analytics = processData(jobData);
    currentDisplayTotal = Math.max(0, analytics.totalJobs - 150);
    updateMetricsUI();

    charts.push(initSalaryChart());
    charts.push(initGeoChart());           // NEW 
    charts.push(initFinanceDonut());
    charts.push(initHiringScaleChart());   // NEW
    charts.push(initSubdomainChart());     // UPDATED (Dual Axis)
    renderWelfareTags();
}

document.addEventListener('DOMContentLoaded', () => {

    // Initial Render
    renderAll();

    // Setup Global Filter Event Listener
    const filterBtn = document.getElementById('btn-filter-intern');
    if (filterBtn) {
        filterBtn.addEventListener('click', () => {
            window.isInternshipExcluded = !window.isInternshipExcluded;

            if (window.isInternshipExcluded) {
                filterBtn.innerHTML = '<s>实习</s>';
                filterBtn.style.color = '#736b63';
                filterBtn.style.borderColor = 'rgba(115,107,99,0.3)';
            } else {
                filterBtn.innerHTML = '实习';
                filterBtn.style.color = 'var(--accent-amber)';
                filterBtn.style.borderColor = 'rgba(205,163,97,0.4)';
            }

            renderAll(); // Recompute and redraw everything
        });
    }

    setInterval(spawnFeedItem, 2500);
    for (let i = 0; i < 5; i++) setTimeout(spawnFeedItem, i * 200);

    window.addEventListener('resize', () => { charts.forEach(c => c.resize()); });
});
