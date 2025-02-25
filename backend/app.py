from flask import Flask, request, jsonify, render_template, session
from flask_cors import CORS
from alpha_api import get_daily_time_series
from gemini_ai import generate_stock_explanation
from company_search import search_company
from chat_service import process_chat_message
import json
import uuid
import os

app = Flask(__name__)
CORS(app)
app.secret_key = "your_secret_key_here"

chat_sessions = {}

@app.route("/")
def home():
    return render_template("chat.html")

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
        
        # Format data for better readability in the prompt
        formatted_data = {
            "symbol": symbol,
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
        return jsonify({"error": str(e)}), 500

@app.route("/search_company", methods=["GET"])
def search_company_endpoint():
    query = request.args.get("query")
    if not query:
        return jsonify({"error": "Missing query parameter"}), 400
    
    try:
        results = search_company(query)
        return jsonify(results)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/chat/start", methods=["POST"])
def start_chat():
    """Initialize a new chat session."""
    print("Starting chat session...")
    session_id = str(uuid.uuid4())
    chat_sessions[session_id] = {
        "history": []
    }
    print(f"Created session: {session_id}")
    return jsonify({"session_id": session_id})

@app.route("/chat/message", methods=["POST"])
def chat_message():
    """Process a chat message and return a response."""
    print("Received chat message")
    data = request.json
    print(f"Request data: {data}")
    
    session_id = data.get("session_id")
    message = data.get("message")
    
    if not session_id or not message:
        print("Missing session_id or message")
        return jsonify({"error": "Missing session_id or message"}), 400
    
    if session_id not in chat_sessions:
        print(f"Invalid session_id: {session_id}")
        print(f"Available sessions: {list(chat_sessions.keys())}")
        return jsonify({"error": "Invalid session_id"}), 400
    
    # Add user message to history
    chat_sessions[session_id]["history"].append({"role": "user", "content": message})
    
    try:
        # Process the message
        response = process_chat_message(
            message, 
            chat_sessions[session_id]["history"]
        )
        
        # Add system response to history
        if response["type"] == "text":
            chat_sessions[session_id]["history"].append({"role": "system", "content": response["content"]})
        elif response["type"] == "company_options":
            chat_sessions[session_id]["history"].append({
                "role": "system", 
                "content": f"I found several companies matching '{response['query']}'. Which one did you mean?",
                "options": response["options"]
            })
        elif response["type"] == "stock_analysis":
            chat_sessions[session_id]["history"].append({
                "role": "system", 
                "content": response["explanation"],
                "symbol": response["symbol"],
                "data": response["data"]
            })
        
        print(f"Sending response: {response['type']}")
        return jsonify(response)
    except Exception as e:
        print(f"Error processing message: {str(e)}")
        return jsonify({"type": "text", "content": f"Error: {str(e)}"}), 500

@app.route("/chat/history", methods=["GET"])
def get_chat_history():
    """Get the chat history for a session."""
    session_id = request.args.get("session_id")
    
    if not session_id:
        return jsonify({"error": "Missing session_id parameter"}), 400
    
    if session_id not in chat_sessions:
        return jsonify({"error": "Invalid session_id"}), 400
    
    return jsonify(chat_sessions[session_id]["history"])

if __name__ == "__main__":
    # Make sure the templates directory exists
    os.makedirs("templates", exist_ok=True)
    app.run(debug=True)