from company_search import search_company
from alpha_api import get_daily_time_series
from gemini_ai import generate_stock_explanation
import json

def process_chat_message(message: str, chat_history=None):
    """Process a chat message and generate an appropriate response."""
    print(f"Processing message: {message}")
    
    if chat_history is None:
        chat_history = []
    
    # Check if this is asking about a company
    if "about" in message.lower() and not any(word in message.lower() for word in ["which", "select", "choose"]):
        # Extract potential company name - this is a simplified approach
        # In a production system, you'd use NLP/NER for better extraction
        words = message.lower().split()
        if "about" in words:
            about_index = words.index("about")
            if about_index + 1 < len(words):
                potential_company = " ".join(words[about_index + 1:])
                # Remove any punctuation at the end
                potential_company = potential_company.rstrip("?.,!")
                
                print(f"Searching for company: {potential_company}")
                
                # Search for the company
                try:
                    search_results = search_company(potential_company)
                    
                    if not search_results:
                        return {"type": "text", "content": f"I couldn't find any company matching '{potential_company}'. Could you try with a different name?"}
                    
                    # Return company options for the user to select
                    return {
                        "type": "company_options",
                        "query": potential_company,
                        "options": search_results[:5]  # Limit to top 5 matches
                    }
                except Exception as e:
                    print(f"Error searching for company: {str(e)}")
                    return {"type": "text", "content": f"I encountered an error while searching for '{potential_company}': {str(e)}"}
    
    # Check if this is selecting a company from options
    elif any(word in message.lower() for word in ["select", "choose"]) and chat_history:
        # Extract the symbol - again, simplified approach
        words = message.split()  # Don't convert to lowercase for stock symbols
        for word in words:
            if word.isupper():  # Most stock symbols are uppercase
                try:
                    print(f"Getting stock data for symbol: {word}")
                    # Get stock data for the selected symbol
                    stock_data = get_daily_time_series(word)
                    
                    # Extract recent data for analysis
                    time_series = stock_data.get("Time Series (Daily)", {})
                    recent_data = dict(list(time_series.items())[:7])
                    
                    # Generate explanation
                    formatted_data = {
                        "symbol": word,
                        "recent_data": recent_data
                    }
                    
                    explanation = generate_stock_explanation(json.dumps(formatted_data, indent=2))
                    
                    return {
                        "type": "stock_analysis",
                        "symbol": word,
                        "data": stock_data,
                        "explanation": explanation
                    }
                except Exception as e:
                    print(f"Error getting stock data: {str(e)}")
                    return {"type": "text", "content": f"I had trouble retrieving data for {word}. Error: {str(e)}"}
        
        return {"type": "text", "content": "I'm not sure which company you'd like to select. Please specify the stock symbol."}
    
    # Default response for other types of messages
    return {"type": "text", "content": "I can help you find information about companies and analyze stocks. Try asking about a specific company like 'do you know about Apple?'"}