# traffic_model_training.py

# Import necessary libraries
import pandas as pd
import numpy as np
import xgboost as xgb
from sklearn.model_selection import train_test_split, TimeSeriesSplit
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score
import joblib
import matplotlib.pyplot as plt
import logging
from datetime import datetime

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def load_and_prepare_data(filepath='traffic_data_prepared.csv'):
    """
    Load and prepare the data for model training
    """
    try:
        logger.info("Loading data from %s", filepath)
        data = pd.read_csv(filepath)
        
        # Define feature columns
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
            'total_volume_lag_1',
            'total_volume_lag_2',
            'total_volume_lag_3',
            'num_events_hour',
            'total_event_weight_day_of_week'
        ]
        
        # Verify all features exist in the dataset
        missing_cols = [col for col in feature_cols if col not in data.columns]
        if missing_cols:
            raise ValueError(f"Missing columns in dataset: {missing_cols}")
            
        # Prepare features and target
        X = data[feature_cols]
        y = data['total_volume']
        
        return X, y, data
        
    except Exception as e:
        logger.error("Error loading data: %s", str(e))
        raise

def split_data(X, y, test_size=0.2):
    """
    Split data into training and testing sets, preserving time series order
    """
    split_index = int((1 - test_size) * len(X))
    X_train = X.iloc[:split_index]
    X_test = X.iloc[split_index:]
    y_train = y.iloc[:split_index]
    y_test = y.iloc[split_index:]
    
    logger.info("Data split - Training set size: %d, Test set size: %d", 
                len(X_train), len(X_test))
    
    return X_train, X_test, y_train, y_test

def train_model(X_train, y_train):
    """
    Train the XGBoost model
    """
    try:
        model = xgb.XGBRegressor(
            objective='reg:squarederror',
            n_estimators=100,
            learning_rate=0.1,
            max_depth=6,
            random_state=42
        )
        
        logger.info("Starting model training...")
        model.fit(
            X_train, 
            y_train,
            eval_set=[(X_train, y_train)],
            verbose=True
        )
        
        return model
        
    except Exception as e:
        logger.error("Error during model training: %s", str(e))
        raise

def evaluate_model(model, X_test, y_test):
    """
    Evaluate the model and return metrics
    """
    try:
        y_pred = model.predict(X_test)
        
        # Calculate metrics
        mse = mean_squared_error(y_test, y_pred)
        rmse = np.sqrt(mse)
        mae = mean_absolute_error(y_test, y_pred)
        r2 = r2_score(y_test, y_pred)
        
        metrics = {
            'RMSE': rmse,
            'MAE': mae,
            'R2': r2
        }
        
        logger.info("Model Evaluation Metrics:")
        for metric_name, value in metrics.items():
            logger.info("%s: %.4f", metric_name, value)
            
        return metrics, y_pred
        
    except Exception as e:
        logger.error("Error during model evaluation: %s", str(e))
        raise

def plot_results(y_test, y_pred, save_path=None):
    """
    Plot and optionally save the actual vs predicted values
    """
    try:
        plt.figure(figsize=(12, 6))
        plt.plot(y_test.reset_index(drop=True), label='Actual', alpha=0.7)
        plt.plot(y_pred, label='Predicted', alpha=0.7)
        plt.title('Actual vs. Predicted Traffic Volume')
        plt.xlabel('Time Steps')
        plt.ylabel('Total Volume')
        plt.legend()
        
        if save_path:
            plt.savefig(save_path)
            logger.info("Plot saved to %s", save_path)
        
        plt.show()
        plt.close()
        
    except Exception as e:
        logger.error("Error creating plot: %s", str(e))
        raise

def save_model(model, filename='xgboost_traffic_model.joblib'):
    """
    Save the trained model
    """
    try:
        joblib.dump(model, filename)
        logger.info("Model saved to %s", filename)
    except Exception as e:
        logger.error("Error saving model: %s", str(e))
        raise

def main():
    try:
        # Load and prepare data
        X, y, data = load_and_prepare_data()
        
        # Split data
        X_train, X_test, y_train, y_test = split_data(X, y)
        
        # Train model
        model = train_model(X_train, y_train)
        
        # Evaluate model
        metrics, y_pred = evaluate_model(model, X_test, y_test)
        
        # Plot results
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        plot_results(y_test, y_pred, save_path=f'results_plot_{timestamp}.png')
        
        # Save model
        save_model(model)
        
        return model, metrics
        
    except Exception as e:
        logger.error("Error in main execution: %s", str(e))
        raise

if __name__ == "__main__":
    main()