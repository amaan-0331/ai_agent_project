from flask import Flask, request, jsonify
from alpha_api import get_daily_time_series
from gemini_ai import generate_stock_explanation
import json

app = Flask(__name__)

@app.route("/")
def home():
    return "Welcome to the Stock Explain App Backend."

@app.route("/fetch_stock", methods=["GET"])
def fetch_stock():
    symbol = request.args.get("symbol")
    if not symbol:
        return jsonify({"error": "Missing symbol parameter"}), 400
    try:
        data = get_daily_time_series(symbol)
        return jsonify(data)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/explain_stock", methods=["GET"])
def explain_stock():
    symbol = request.args.get("symbol")
    if not symbol:
        return jsonify({"error": "Missing symbol parameter"}), 400
    
    try:
        # Get stock data
        stock_data = get_daily_time_series(symbol)
        
        # Extract the most recent 7 days of data for analysis
        time_series = stock_data.get("Time Series (Daily)", {})
        recent_data = dict(list(time_series.items())[:7])
        
        # Extract metadata if available
        metadata = {k: v for k, v in stock_data.items() if k != "Time Series (Daily)"}
        
        # Format data for better readability in the prompt
        formatted_data = {
            "symbol": symbol,
            "metadata": metadata,
            "recent_data": recent_data
        }
        
        # Generate explanation using Gemini
        explanation = generate_stock_explanation(json.dumps(formatted_data, indent=2))
        
        # Return both the raw data and the explanation
        return jsonify({
            "symbol": symbol,
            "data": stock_data,
            "explanation": explanation
        })
        
    except Exception as e:
        return jsonify({"error": str(e), "traceback": str(e.__traceback__)}), 500

if __name__ == "__main__":
    app.run(debug=True)