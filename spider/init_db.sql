CREATE DATABASE IF NOT EXISTS spider_db DEFAULT CHARSET utf8mb4;
USE spider_db;

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
