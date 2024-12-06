# traffic_model_training.py

# Import necessary libraries
import pandas as pd
import numpy as np
import xgboost as xgb
from sklearn.model_selection import train_test_split, TimeSeriesSplit, GridSearchCV
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
import joblib  # For saving the model
import matplotlib.pyplot as plt

# -------------------------------
# Step 1: Load the Prepared Data
# -------------------------------

# Load the prepared data from the feature engineering script
data = pd.read_csv('traffic_data_prepared.csv')

# -------------------------------
# Step 2: Prepare Features and Target Variable
# -------------------------------

# Define the feature columns (make sure to match the columns from the prepared data)
feature_cols = [
    'num_events',
    'total_event_weight',
    'avg_distance_to_events',
    'min_distance_to_event',
    'avg_event_duration',
    'avg_time_since_event_start',
    'avg_time_until_event_end',
    'hour',
    'day_of_week',
    'is_weekend',
    'signal_id_encoded',
    # Lag features
    'total_volume_lag_1',
    'total_volume_lag_2',
    'total_volume_lag_3',
    # Interaction features
    'num_events_hour',
    'total_event_weight_day_of_week'
    # Include event category features if used
    # 'event_category_Music',
    # 'event_category_Sports',
    # Add other event categories as needed
]

# Prepare the feature matrix (X) and target vector (y)
X = data[feature_cols]
y = data['total_volume']

# -------------------------------
# Step 3: Split Data into Training and Testing Sets
# -------------------------------

# Since traffic data is time-series in nature, it's important to avoid shuffling
# We'll split the data based on time, keeping the last 20% as the test set
split_index = int(0.8 * len(data))
X_train = X.iloc[:split_index]
X_test = X.iloc[split_index:]
y_train = y.iloc[:split_index]
y_test = y.iloc[split_index:]

# -------------------------------
# Step 4: Train the XGBoost Model
# -------------------------------

# Initialize the XGBoost regressor
model = xgb.XGBRegressor(
    objective='reg:squarederror',
    n_estimators=100,
    learning_rate=0.1,
    max_depth=6,
    random_state=42
)

# Train the model
print("Training the model...")
model.fit(X_train, y_train)

# -------------------------------
# Step 5: Evaluate the Model
# -------------------------------

# Make predictions on the test set
y_pred = model.predict(X_test)

# Calculate evaluation metrics
rmse = mean_squared_error(y_test, y_pred, squared=False)
mae = mean_absolute_error(y_test, y_pred)
r2 = r2_score(y_test, y_pred)

print(f'\nModel Evaluation Metrics:')
print(f'RMSE: {rmse:.2f}')
print(f'MAE: {mae:.2f}')
print(f'R² Score: {r2:.4f}')

# Optionally, plot the predicted vs. actual values
plt.figure(figsize=(12, 6))
plt.plot(y_test.reset_index(drop=True), label='Actual')
plt.plot(y_pred, label='Predicted')
plt.title('Actual vs. Predicted Traffic Volume')
plt.xlabel('Time Steps')
plt.ylabel('Total Volume')
plt.legend()
plt.show()

# -------------------------------
# Step 6: Save the Trained Model
# -------------------------------

# Save the model to a file for future use
model_filename = 'xgboost_traffic_model.joblib'
joblib.dump(model, model_filename)
print(f'\nModel saved to {model_filename}')
