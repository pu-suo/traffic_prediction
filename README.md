# traffic_prediction

# dependencies
```
# for macosx
brew install libomp
```


# backend setup
```
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
