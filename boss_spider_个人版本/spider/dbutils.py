import pymysql


class DBUtils:
    def __init__(self, host, user, password, db, port=3306, charset='utf8'):
        self.conn = pymysql.connect(host=host, user=user, password=password, db=db, port=port, charset=charset)
        self.cursor = self.conn.cursor(pymysql.cursors.DictCursor)

    def select_all(self, sql, args=None):
        self.cursor.execute(sql, args)
        result = self.cursor.fetchall()
        return result

    def select_n(self, sql, n, args=None):
        self.cursor.execute(sql, args)
        result = self.cursor.fetchmany(n)
        return result

    def select_one(self, sql, args=None):
        self.cursor.execute(sql, args)
        result = self.cursor.fetchone()
        return result

    def insert_data(self, sql, args=None):
        self.cursor.execute(sql, args)
        self.conn.commit()
        return self.cursor.rowcount

    def update_data(self, sql, args=None):
        self.cursor.execute(sql, args)
        self.conn.commit()
        return self.cursor.rowcount

    def delete_data(self, sql, args=None):
        self.cursor.execute(sql, args)
        self.conn.commit()
        return self.cursor.rowcount

    def close(self):
        self.cursor.close()
        self.conn.close()




# 定义 main 函数
if __name__ == '__main__':
    # 实例化 DBUtils
    db = DBUtils('localhost', 'root', '123456', 'spring')

    # 测试查询所有数据
    """ret = db.select_all("select * from t_user")
    for r in ret:
        print(r)"""

    # 测试查询前 n 条数据
    """ret = db.select_n("select * from t_user", 3)
    for r in ret:
        print(r)"""

    # 测试查询 1 条数据
    """ret = db.select_one("select * from t_user where username = %s and password = %s", ['admin', 'admin'])
    print(ret)"""

    # 测试插入数据
    """rows = db.insert_data("insert into t_user(username,password) values(%s,%s)", ['李玉梅', '000000'])
    print(rows)"""

    # 测试更新数据
    """rows = db.update_data("update t_user set password = %s where username = %s", ['123456', '李玉'])
    print(rows)"""

    # 测试删除数据
    """rows = db.delete_data("delete from t_user where username = %s", ['李玉梅'])
    print(rows)"""

    # 关闭数据库连接
    db.close()