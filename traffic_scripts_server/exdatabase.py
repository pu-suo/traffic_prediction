import mysql.connector
from mysql.connector import Error

def create_database():
    try:
        # Connect to MySQL server
        connection = mysql.connector.connect(
            host="localhost",
            user="bruh",
            password="bruh"
        )
        
        if connection.is_connected():
            cursor = connection.cursor()
            
            # Create database
            cursor.execute("CREATE DATABASE IF NOT EXISTS example_db")
            print("Database created successfully")
            
            # Switch to the new database
            cursor.execute("USE example_db")
            
            # Create a sample table
            create_table_query = """
            CREATE TABLE IF NOT EXISTS employees (
                id INT AUTO_INCREMENT PRIMARY KEY,
                name VARCHAR(100) NOT NULL,
                email VARCHAR(100) UNIQUE,
                department VARCHAR(100),
                salary DECIMAL(10, 2),
                hire_date DATE
            )
            """
            cursor.execute(create_table_query)
            print("Table 'employees' created successfully")
            
            # Insert sample data
            insert_query = """
            INSERT INTO employees (name, email, department, salary, hire_date)
            VALUES
                ('John Doe', 'john@example.com', 'IT', 75000.00, '2023-01-15'),
                ('Jane Smith', 'jane@example.com', 'HR', 65000.00, '2023-02-01'),
                ('Mike Johnson', 'mike@example.com', 'Sales', 80000.00, '2023-03-10')
            """
            cursor.execute(insert_query)
            connection.commit()
            print("Sample data inserted successfully")
            
            # Perform a sample query
            cursor.execute("SELECT * FROM employees")
            rows = cursor.fetchall()
            print("\nEmployee Records:")
            for row in rows:
                print(row)
                
    except Error as e:
        print(f"Error: {e}")
    finally:
        if connection.is_connected():
            cursor.close()
            connection.close()
            print("\nMySQL connection closed")

def main():
    create_database()

if __name__ == "__main__":
    main()