import pymysql
from dbutils import DBUtils

def migrate():
    # 这里的连接信息与 bossspider.py 一致
    host = 'localhost'
    user = 'root'
    password = 'aq2488569!'
    db_name = 'spider_db'

    print(f"Connecting to database {db_name}...")
    try:
        # 建立连接检查/创建表
        conn = pymysql.connect(host=host, user=user, password=password, charset='utf8mb4')
        cursor = conn.cursor()
        cursor.execute(f"CREATE DATABASE IF NOT EXISTS {db_name} DEFAULT CHARSET utf8mb4;")
        cursor.execute(f"USE {db_name};")
        
        # 确保基础表存在
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS job_info (
            id INT AUTO_INCREMENT PRIMARY KEY,
            main_category VARCHAR(100),
            sub_category VARCHAR(100),
            job_name VARCHAR(100) NOT NULL,
            job_area VARCHAR(50),
            job_company VARCHAR(100),
            job_industry VARCHAR(100),
            job_finance VARCHAR(50),
            job_scale VARCHAR(50),
            job_welfare TEXT,
            salary_range VARCHAR(50),
            salary_type VARCHAR(50),
            job_experience VARCHAR(50),
            job_education VARCHAR(50),
            job_tag_list TEXT,
            search_keyword VARCHAR(100),
            create_time DATE,
            UNIQUE KEY idx_job_company (job_name, job_company, job_area) 
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        """)
        conn.commit()

        # 需要检查并添加的列及其定义
        new_columns = [
            ("job_id", "VARCHAR(100)"),
            ("post_description", "TEXT"),
            ("deliver_status", "VARCHAR(50)"),
            ("filter_reason", "VARCHAR(255)"),
            ("ai_score", "INT"),
            ("ai_reason", "TEXT"),
            ("longitude", "DOUBLE"),
            ("latitude", "DOUBLE"),
            ("address_detail", "VARCHAR(255)"),
            ("boss_name", "VARCHAR(100)"),
            ("boss_title", "VARCHAR(100)"),
            ("boss_active", "VARCHAR(100)"),
        ]

        # 获取现有列
        cursor.execute("DESCRIBE job_info;")
        existing_columns = [row[0] for row in cursor.fetchall()]

        for col_name, col_type in new_columns:
            if col_name not in existing_columns:
                print(f"Adding column: {col_name}...")
                cursor.execute(f"ALTER TABLE job_info ADD COLUMN {col_name} {col_type};")
                conn.commit()
            else:
                print(f"Column {col_name} already exists.")

        # 检查是否已为 job_id 创建唯一索引
        cursor.execute("SHOW INDEX FROM job_info;")
        indexes = [row[2] for row in cursor.fetchall()]
        if "idx_job_id" not in indexes and "job_id" not in indexes:
            print("Creating UNIQUE INDEX on job_id...")
            cursor.execute("ALTER TABLE job_info ADD UNIQUE INDEX idx_job_id (job_id);")
            conn.commit()
            
        print("Database migration completed successfully!")
    except Exception as e:
        print(f"Migration failed: {e}")
    finally:
        if 'conn' in locals() and conn:
            conn.close()

if __name__ == '__main__':
    migrate()
