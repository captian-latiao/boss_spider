import os
import csv
import json
import datetime
from flask import Flask, request, jsonify

app = Flask(__name__)

# 定义数据文件与目录路径（相对于 app.py 所在的 spider 目录）
DATA_JS_PATH = os.path.join(os.path.dirname(__file__), '../dashboard/data.js')
CSV_PATH = os.path.join(os.path.dirname(__file__), 'jobs.csv')
JOBDATA_DIR = os.path.join(os.path.dirname(__file__), '../jobdata')

# 新模版标准表头（共 21 个精简字段）
NEW_FIELDNAMES = [
    'job_id', 'main_category', 'sub_category', 'job_name', 'job_area', 'job_company',
    'job_industry', 'job_finance', 'job_scale', 'job_welfare', 'salary_range', 'salary_type',
    'job_experience', 'job_tag_list', 'post_description',
    'deliver_status', 'filter_reason', 'filter_detail', 'address_detail', 'boss_active', 'create_time'
]

# 手动处理 CORS
@app.after_request
def after_request(response):
    response.headers.add('Access-Control-Allow-Origin', '*')
    response.headers.add('Access-Control-Allow-Headers', 'Content-Type,Authorization')
    response.headers.add('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,OPTIONS')
    return response

# 获取当周归档 CSV 路径 (格式: jobdata/YYYY-MM/week_WW.csv)
def get_weekly_csv_path():
    today = datetime.date.today()
    month_str = today.strftime('%Y-%m')
    week_num = today.isocalendar()[1]

    month_dir = os.path.join(JOBDATA_DIR, month_str)
    os.makedirs(month_dir, exist_ok=True)

    filename = f"week_{week_num:02d}.csv"
    return os.path.join(month_dir, filename)

# 载入历史数据（从 data.js, 旧 jobs.csv 以及 jobdata/ 下的所有周度 CSV 综合加载）
def load_historical_data():
    all_jobs_by_id = {}
    all_jobs_by_info = {}

    def add_or_merge(job):
        job_id = job.get('job_id')
        company = job.get('job_company', '')
        name = job.get('job_name', '')
        area = job.get('job_area', '')
        
        info_key = f"{company}_{name}_{area}"

        existing = None
        if job_id and job_id in all_jobs_by_id:
            existing = all_jobs_by_id[job_id]
        elif info_key in all_jobs_by_info:
            existing = all_jobs_by_info[info_key]

        if existing:
            for k, v in job.items():
                if v is not None and v != '':
                    existing[k] = v
            if job_id:
                all_jobs_by_id[job_id] = existing
            all_jobs_by_info[info_key] = existing
        else:
            if job_id:
                all_jobs_by_id[job_id] = job
            all_jobs_by_info[info_key] = job

    # 1. 尝试从已有的 data.js 加载
    if os.path.exists(DATA_JS_PATH):
        try:
            with open(DATA_JS_PATH, 'r', encoding='utf-8') as f:
                content = f.read().strip()
                if content.startswith('const jobData = '):
                    json_str = content[len('const jobData = '):]
                    if json_str.endswith(';'):
                        json_str = json_str[:-1]
                    jobs_list = json.loads(json_str)
                    for job in jobs_list:
                        add_or_merge(job)
        except Exception as e:
            print(f"Error loading historical data from data.js: {e}")

    # 2. 尝试从旧 jobs.csv 加载
    if os.path.exists(CSV_PATH):
        try:
            with open(CSV_PATH, 'r', encoding='utf-8-sig') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    add_or_merge(dict(row))
        except Exception as e:
            print(f"Error loading from CSV: {e}")

    # 3. 扫描并从 jobdata/ 目录下所有按月/按周 CSV 动态加载
    if os.path.exists(JOBDATA_DIR):
        for root, _, files in os.walk(JOBDATA_DIR):
            for file in files:
                if file.endswith('.csv'):
                    file_path = os.path.join(root, file)
                    try:
                        with open(file_path, 'r', encoding='utf-8-sig') as f:
                            reader = csv.DictReader(f)
                            for row in reader:
                                add_or_merge(dict(row))
                    except Exception as e:
                        print(f"Error loading weekly CSV {file_path}: {e}")

    result = {}
    for info_key, job in all_jobs_by_info.items():
        key = job.get('job_id') or info_key
        result[key] = job
    return result

# 保存新数据到当周归档 CSV 和 dashboard/data.js
def save_job_to_weekly_csv_and_js(new_job, all_jobs):
    # 1. 更新 dashboard/data.js
    jobs_list = list(all_jobs.values())
    try:
        with open(DATA_JS_PATH, 'w', encoding='utf-8') as f:
            f.write(f"const jobData = {json.dumps(jobs_list, ensure_ascii=False)};")
    except Exception as e:
        print(f"Failed to write data.js: {e}")

    # 2. 写入/更新当周的归档 CSV (jobdata/YYYY-MM/week_WW.csv)
    weekly_csv_path = get_weekly_csv_path()
    weekly_jobs = {}

    # 读取已有周数据（避免重复追加）
    if os.path.exists(weekly_csv_path):
        try:
            with open(weekly_csv_path, 'r', encoding='utf-8-sig') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    jid = row.get('job_id')
                    if jid:
                        weekly_jobs[jid] = dict(row)
        except Exception as e:
            print(f"Error reading existing weekly CSV: {e}")

    weekly_jobs[new_job['job_id']] = new_job

    try:
        with open(weekly_csv_path, 'w', newline='', encoding='utf-8-sig') as f:
            writer = csv.DictWriter(f, fieldnames=NEW_FIELDNAMES)
            writer.writeheader()
            for jid, jdata in weekly_jobs.items():
                row = {field: jdata.get(field, '') for field in NEW_FIELDNAMES}
                writer.writerow(row)
    except Exception as e:
        print(f"Failed to write weekly CSV: {e}")

@app.route('/api/save_job', methods=['POST', 'OPTIONS'])
def save_job():
    if request.method == 'OPTIONS':
        return jsonify({"status": "ok"}), 200

    data = request.json
    if not data:
        return jsonify({"code": 400, "message": "Missing JSON data"}), 400

    # 载入现有内存数据
    all_jobs = load_historical_data()

    job_id = data.get('encryptJobId')
    if not job_id:
        return jsonify({"code": 400, "message": "encryptJobId is required"}), 400

    job_name = data.get('jobName', '')
    job_company = data.get('brandName', '')
    
    city_name = data.get('cityName', '')
    area_district = data.get('areaDistrict', '')
    business_district = data.get('businessDistrict', '')
    area_parts = [p for p in [city_name, area_district, business_district] if p]
    job_area = "·".join(area_parts) if area_parts else city_name

    job_industry = data.get('brandIndustry', '')
    job_finance = data.get('brandStageName', '')
    job_scale = data.get('brandScaleName', '')
    
    welfare_list = data.get('welfareList')
    job_welfare = ",".join(welfare_list) if isinstance(welfare_list, list) else (welfare_list or '')

    salary_desc = data.get('salaryDesc', '')
    salary_range = salary_desc
    salary_type = '12薪'
    if '·' in salary_desc:
        parts = salary_desc.split('·')
        salary_range = parts[0]
        salary_type = parts[1]
    elif '薪' in salary_desc:
        import re
        match = re.search(r'(\d+-\d+K)(\d+薪)?', salary_desc)
        if match:
            salary_range = match.group(1)
            salary_type = match.group(2) if match.group(2) else '12薪'

    job_experience = data.get('jobExperience', '')

    skills = data.get('skills')
    job_tag_list = ",".join(skills) if isinstance(skills, list) else (skills or '')

    card = data.get('card', {}) or {}
    post_description = card.get('postDescription', '')
    address_detail = card.get('address', '')
    
    boss_active = card.get('activeTimeDesc', '')

    main_category = data.get('main_category', '产品')
    sub_category = data.get('sub_category', '产品经理')

    status_info = data.get('status', {}) or {}
    deliver_status = status_info.get('status', 'pending')
    filter_reason = status_info.get('msg', '')
    filter_detail = status_info.get('detail', '')
    if filter_detail == filter_reason:
        filter_detail = ''

    create_time = datetime.date.today().strftime('%Y/%m/%d')

    # 构建全新的精简职位对象 (21 字段新模板)
    new_job = {
        'job_id': job_id,
        'main_category': main_category,
        'sub_category': sub_category,
        'job_name': job_name,
        'job_area': job_area,
        'job_company': job_company,
        'job_industry': job_industry,
        'job_finance': job_finance,
        'job_scale': job_scale,
        'job_welfare': job_welfare,
        'salary_range': salary_range,
        'salary_type': salary_type,
        'job_experience': job_experience,
        'job_tag_list': job_tag_list,
        'post_description': post_description,
        'deliver_status': deliver_status,
        'filter_reason': filter_reason,
        'filter_detail': filter_detail,
        'address_detail': address_detail,
        'boss_active': boss_active,
        'create_time': create_time
    }

    all_jobs[job_id] = new_job

    # 持久化保存到当周归档 CSV (jobdata/YYYY-MM/week_WW.csv) 和 dashboard/data.js
    save_job_to_weekly_csv_and_js(new_job, all_jobs)

    weekly_csv = get_weekly_csv_path()
    print(f"[{create_time}] Successfully saved job to weekly archive ({weekly_csv}): {job_company} - {job_name}")
    return jsonify({"code": 200, "message": "Success"}), 200

@app.route('/api/get_resume', methods=['GET'])
def get_resume():
    resume_path = os.path.join(os.path.dirname(__file__), '../dashboard/resume.md')
    if os.path.exists(resume_path):
        try:
            with open(resume_path, 'r', encoding='utf-8') as f:
                content = f.read()
            return jsonify({"code": 200, "content": content}), 200
        except Exception as e:
            return jsonify({"code": 500, "message": f"Error reading file: {str(e)}"}), 500
    else:
        return jsonify({"code": 404, "message": "Resume file not found"}), 404

if __name__ == '__main__':
    print("Starting Boss Helper local weekly CSV sync server on port 5005...")
    app.run(host='0.0.0.0', port=5005, debug=True)
