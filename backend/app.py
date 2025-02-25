from flask import Flask, request, jsonify
from alpha_api import get_daily_time_series

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

if __name__ == "__main__":
    app.run(debug=True)
