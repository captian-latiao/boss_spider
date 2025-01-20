# | 更新人 | 版本 | 日期 | 更新内容 |
# | --- | --- | --- | --- |
# | CaptianLatiao | 0.1 | 2024-01-15 | 1.新增可定义参数-职业类型 2.新增自动翻页 3.新增关键字查询 |
# | CaptianLatiao | 0.2 | 2024-01-17 | 优化目标元素定位方式 |

import datetime
import time
import re

from selenium import webdriver
from selenium.webdriver.common.by import By
from dbutils import DBUtils
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

# 翻页函数
def next_page():
    try:
        # 确保“下一页”按钮可点击
        next_page_btn = WebDriverWait(browser, 10).until(
            EC.element_to_be_clickable((By.CLASS_NAME, 'ui-icon-arrow-right'))
        )
        if 'disabled' in next_page_btn.find_element(by=By.XPATH, value='..').get_attribute('class'):
            print("No more pages to navigate.")
            return False
        
        # 点击下一页按钮
        next_page_btn.click()
        time.sleep(5)
        
        # 等待新页面加载完成
        WebDriverWait(browser, 10).until(
            EC.presence_of_all_elements_located((By.CLASS_NAME, "job-card-wrapper"))
        )
        print("Successfully navigated to the next page.")
        return True
    except Exception as e:
        print(f"Error navigating to the next page: {e}")
        return False

# 类型选择函数
def select_category(main_category_name, sub_category_name):
    try:
        # 模拟点击分类
        show_ele = browser.find_element(By.XPATH, f'//b[text()="{main_category_name}"]')
        show_ele.click()

        main_category = browser.find_element(By.XPATH, f'//p[@class="menu-article" and text()="{main_category_name}"]')
        print(f"Located main category: {main_category_name}")

        time.sleep(3)

        # 定位二级分类
        sub_category = main_category.find_element(By.XPATH, f'./following-sibling::ul//a[text()="{sub_category_name}"]')
        print(f"Located sub-category: {sub_category_name}")

        # 点击二级分类
        sub_category.click()
        print(f"Clicked on sub-category: {sub_category_name}")

        # 等待加载
        time.sleep(5)

        return main_category_name, sub_category_name
    except Exception as e:
        print(f"Error selecting category: {e}")

# 关键字筛选
def search_jobs(keyword):
    try:
        search_input = WebDriverWait(browser, 10).until(
            EC.presence_of_element_located((By.XPATH, '//input[@placeholder="搜索职位、公司"]'))
        )
        search_input.clear()  # Clear the input box
        search_input.send_keys(keyword)  # Input the search keyword
        from selenium.webdriver.common.keys import Keys
        print(f"Simulated input keyword: {keyword}")
        search_input.send_keys(Keys.RETURN)  # Simulate pressing Enter
        time.sleep(5)  # Wait for search results to load
    except Exception as e:
        print(f"Error in search_jobs: {e}")

browser = webdriver.Edge()

## 自定义参数
# 目标城市
index_url = 'https://www.zhipin.com/hangzhou/?ka=city-sites-101210100' 
browser.get(index_url)
time.sleep(3)
# 目标岗位
main_category, sub_category = select_category("产品", "产品经理")  
time.sleep(5)
# 关键字
search_keyword = "大模型"
search_jobs(search_keyword)
time.sleep(5)
# 最大翻页次数
MAX_PAGES = 10  

# 获取当前日期
today = datetime.date.today().strftime('%Y-%m-%d')
print(f"Today's date: {today}")

# 抓取当前分类的职位数据
try:
    page_count = 0  # 当前分类下的翻页次数计数
    while page_count < MAX_PAGES:
        # 模拟滑动页面，加载数据
        browser.execute_script("window.scrollTo(0, document.body.scrollHeight-1500);")
        time.sleep(5)

        # 抓取职位数据
        job_detail = browser.find_elements(By.CLASS_NAME, "job-card-wrapper")
        time.sleep(5)
        for job in job_detail:
            db = DBUtils('localhost', 'root', 'Aq2488569!', 'spider_db')
            try:
                # 抓取职位名称
                job_name = job.find_element(By.CLASS_NAME, "job-name").text.strip()   

                # 抓取所在地址
                job_area = job.find_element(By.CLASS_NAME, "job-area").text.strip()
                
                # 抓取公司名称
                job_company = job.find_element(By.CLASS_NAME, "company-name").text.strip()

                # 抓取公司基本信息
                company_tag_elements = job.find_elements(By.CSS_SELECTOR, ".company-tag-list li")
                company_tag_list = [element.text.strip() for element in company_tag_elements]
                # 抓取行业
                job_industry = company_tag_list[0] if len(company_tag_list) > 0 else None
                # 抓取融资信息
                job_finance = company_tag_list[1] if len(company_tag_list) > 1 else None
                # 抓取公司规模
                job_scale = company_tag_list[2] if len(company_tag_list) > 2 else None
                
                # 抓取公司福利
                try:
                    job_welfare = job.find_element(By.CLASS_NAME, "info-desc").text.strip()
                except:
                    job_welfare = '无'

                # 抓取薪资&薪资结构
                salary_element = job.find_element(By.CLASS_NAME, "salary").text.strip()
                salary_pattern = r"(\d+-\d+K)(?:[·\s]?)?(\d+薪)?"
                match = re.search(salary_pattern, salary_element)
                if match:
                    salary_range = match.group(1)
                    salary_type = match.group(2) if match.group(2) else None
                else:
                    salary_range = salary_element
                    salary_type = None

                # 抓取岗位基本需求
                job_basic_elements = job.find_elements(By.CSS_SELECTOR, ".job-info .tag-list li")
                job_basic_list = [element.text.strip() for element in job_basic_elements]
                # 工作经验
                job_experience = job_basic_list[0] if len(job_basic_list) > 0 else None
                # 学历需求
                job_education = job_basic_list[1] if len(job_basic_list) > 1 else None

                # 抓取岗位tag
                job_tag_elements = job.find_elements(By.CSS_SELECTOR, ".job-card-footer .tag-list li")
                job_tag_list = ",".join([element.text.strip() for element in job_tag_elements])
                
                print(main_category, sub_category, job_name, job_area, job_company, job_industry, job_finance, job_scale, job_welfare, salary_range, salary_type, job_experience, job_education, job_tag_list)
                # 保存到数据库
                db.insert_data(
                    "insert ignore into job_info(main_category, sub_category, job_name, job_area, job_company, job_industry, job_finance, job_scale, job_welfare, salary_range, salary_type, job_experience, job_education, job_tag_list, search_keyword, create_time) values(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)",
                    args=(main_category, sub_category, job_name, job_area, job_company, job_industry, job_finance, 
                          job_scale, job_welfare, salary_range, salary_type, job_experience, job_education, job_tag_list, search_keyword, today))
            finally:
                db.close()

        # 判断是否需要翻页
        if not next_page():
            break
        page_count += 1
        print(f"Page {page_count}/{MAX_PAGES} completed.")

except Exception as e:
    print(f"Error: {e}")



    