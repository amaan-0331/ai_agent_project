import os
import requests

FMP_API_KEY = os.environ.get("FMP_API_KEY")
if not FMP_API_KEY:
    raise ValueError("The environment variable FMP_API_KEY is not set.")

BASE_URL = "https://financialmodelingprep.com/stable"

def search_company(query: str):
    """Search for companies matching the query using Financial Modeling Prep API."""
    params = {
        "query": query,
        "apikey": FMP_API_KEY,
    }
    
    response = requests.get(f"{BASE_URL}/search-name", params=params)
    response.raise_for_status()
    return response.json()