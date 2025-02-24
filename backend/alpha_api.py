import requests
import os

# Option 1: Read from environment variable
ALPHAVANTAGE_API_KEY = "0U4RNH16FUMQZEIR"

# Option 2: Directly import from a credentials file if you have a plain text file.
# For example, if credentials/api_key.txt contains only your API key:
# with open(os.path.join("..", "credentials", "api_key.txt"), "r") as f:
#     ALPHAVANTAGE_API_KEY = f.read().strip()

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

if __name__ == "__main__":
    # Test the module; run "python alpha_api.py" to see sample output.
    symbol = "AAPL"
    data = get_daily_time_series(symbol)
    print(f"Data for {symbol}:")
    print(data)
