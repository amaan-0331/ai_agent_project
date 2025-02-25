import os
import requests

ALPHAVANTAGE_API_KEY = os.environ.get("ALPHAVANTAGE_API_KEY")
if not ALPHAVANTAGE_API_KEY:
    # Fallback if needed or raise an error.
    raise ValueError("The environment variable ALPHAVANTAGE_API_KEY is not set.")

BASE_URL = "https://www.alphavantage.co/query"

def get_daily_time_series(symbol: str):
    params = {
        "function": "TIME_SERIES_DAILY",
        "symbol": symbol,
        "apikey": ALPHAVANTAGE_API_KEY,
    }
    response = requests.get(BASE_URL, params=params)
    response.raise_for_status()
    return response.json()
