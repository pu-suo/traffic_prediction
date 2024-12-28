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
