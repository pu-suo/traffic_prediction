# traffic_prediction

# dependencies
```
# for macosx
brew install libomp
```


# backend setup
```

# for current usage, just go to root dir and enter
source venv/bin/activate

# but if venv has not been created, follow the below steps

# go to root dir
python3 -m venv venv
source venv/bin/activate

cd traffic_scripts_server

# for doc purposes
pip install pipreqs
pipreqs .

# all you actually need
pip install -r requirements.txt

# run flask server
flask --app app run 
```

# database setup
```
# install this
brew install mysql

brew services start mysql

# if needed, prob don't
pip install mysql-connector-python

# for development purposes (testing mysql console)
mysql -u root

# for importing into database
mysqldump -u bruh -p example_db > example_db_backup.sql

mysql -h YOUR-RDS-ENDPOINT -u YOUR-RDS-USERNAME -p example_db < example_db_backup.sql
```

# some notes
```
Get predictions offline and then upload the sql database onto AWS for cost efficiency

```