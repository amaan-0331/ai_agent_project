# chat_service.py
from company_search import search_company
from alpha_api import get_daily_time_series
from gemini_ai import generate_stock_explanation
import json
import spacy
import re

# Load spaCy model - you'll need to install this with: pip install spacy && python -m spacy download en_core_web_sm
nlp = spacy.load("en_core_web_sm")

def extract_company_name(message):
    """Extract potential company names using NER."""
    doc = nlp(message)
    
    # Look for organizations (ORG) and products (PRODUCT) in the text
    org_entities = [ent.text for ent in doc.ents if ent.label_ in ["ORG", "PRODUCT"]]
    
    # If we found entities, return the first one
    if org_entities:
        return org_entities[0]
    
    # Fallback: look for words after "about" if no entities found
    about_pattern = re.compile(r'about\s+([^?.,!]+)', re.IGNORECASE)
    match = about_pattern.search(message)
    if match:
        return match.group(1).strip()
    
    return None

def extract_stock_symbol(message):
    """Extract potential stock symbols from the message."""
    # Look for uppercase words that might be stock symbols (2-5 characters)
    symbol_pattern = re.compile(r'\b[A-Z]{2,5}\b')
    symbols = symbol_pattern.findall(message)
    
    # Also check for common phrases like "symbol XYZ" or "ticker ABC"
    explicit_pattern = re.compile(r'(?:symbol|ticker)\s+([A-Z]{2,5})', re.IGNORECASE)
    explicit_match = explicit_pattern.search(message)
    
    if explicit_match:
        return explicit_match.group(1)
    elif symbols:
        return symbols[0]
    
    return None

def detect_intent(message):
    """Determine the user's intent from the message."""
    message_lower = message.lower()
    
    # Check for company information intent
    if any(phrase in message_lower for phrase in ["about", "tell me about", "info on", "information on", "know about"]):
        return "company_info"
    
    # Check for stock selection intent
    if any(phrase in message_lower for phrase in ["select", "choose", "pick", "use", "get data for"]):
        return "select_stock"
    
    # Check for stock analysis intent
    if any(phrase in message_lower for phrase in ["analyze", "analysis", "how is", "performance of", "stock price"]):
        return "stock_analysis"
    
    # Default intent
    return "general_query"

def process_chat_message(message: str, chat_history=None):
    """Process a chat message and generate an appropriate response using NLP."""
    print(f"Processing message: {message}")
    
    if chat_history is None:
        chat_history = []
    
    # Detect the user's intent
    intent = detect_intent(message)
    print(f"Detected intent: {intent}")
    
    # Handle company information intent
    if intent == "company_info":
        company_name = extract_company_name(message)
        
        if not company_name:
            return {"type": "text", "content": "I couldn't identify a company name in your message. Could you specify which company you're interested in?"}
        
        print(f"Extracted company name: {company_name}")
        
        try:
            search_results = search_company(company_name)
            
            if not search_results:
                return {"type": "text", "content": f"I couldn't find any company matching '{company_name}'. Could you try with a different name?"}
            
            # Return company options for the user to select
            return {
                "type": "company_options",
                "query": company_name,
                "options": search_results[:5]  # Limit to top 5 matches
            }
        except Exception as e:
            print(f"Error searching for company: {str(e)}")
            return {"type": "text", "content": f"I encountered an error while searching for '{company_name}': {str(e)}"}
    
    # Handle stock selection intent
    elif intent == "select_stock":
        symbol = extract_stock_symbol(message)
        
        if not symbol:
            # Check if the previous message provided options
            for msg in reversed(chat_history):
                if msg.get("role") == "system" and msg.get("options"):
                    # User is likely responding to options but didn't provide a symbol
                    return {"type": "text", "content": "Please specify which company you'd like to select by providing the stock symbol (e.g., AAPL for Apple)."}
            
            return {"type": "text", "content": "I couldn't identify a stock symbol in your message. Please specify which stock you're interested in."}
        
        try:
            print(f"Getting stock data for symbol: {symbol}")
            # Get stock data for the selected symbol
            stock_data = get_daily_time_series(symbol)
            
            # Extract recent data for analysis
            time_series = stock_data.get("Time Series (Daily)", {})
            recent_data = dict(list(time_series.items())[:7])
            
            # Generate explanation
            formatted_data = {
                "symbol": symbol,
                "recent_data": recent_data
            }
            
            explanation = generate_stock_explanation(json.dumps(formatted_data, indent=2))
            
            return {
                "type": "stock_analysis",
                "symbol": symbol,
                "data": stock_data,
                "explanation": explanation
            }
        except Exception as e:
            print(f"Error getting stock data: {str(e)}")
            return {"type": "text", "content": f"I had trouble retrieving data for {symbol}. Error: {str(e)}"}
    
    # Handle stock analysis intent
    elif intent == "stock_analysis":
        symbol = extract_stock_symbol(message)
        
        if not symbol:
            company_name = extract_company_name(message)
            if company_name:
                # Try to find the company first
                try:
                    search_results = search_company(company_name)
                    
                    if not search_results:
                        return {"type": "text", "content": f"I couldn't find any company matching '{company_name}'. Could you try with a different name?"}
                    
                    # Return company options for the user to select
                    return {
                        "type": "company_options",
                        "query": company_name,
                        "options": search_results[:5]  # Limit to top 5 matches
                    }
                except Exception as e:
                    print(f"Error searching for company: {str(e)}")
                    return {"type": "text", "content": f"I encountered an error while searching for '{company_name}': {str(e)}"}
            else:
                return {"type": "text", "content": "I couldn't identify which stock you'd like to analyze. Please specify a company name or stock symbol."}
        
        # Process the same as stock selection since we have a symbol
        try:
            print(f"Getting stock data for symbol: {symbol}")
            stock_data = get_daily_time_series(symbol)
            
            time_series = stock_data.get("Time Series (Daily)", {})
            recent_data = dict(list(time_series.items())[:7])
            
            formatted_data = {
                "symbol": symbol,
                "recent_data": recent_data
            }
            
            explanation = generate_stock_explanation(json.dumps(formatted_data, indent=2))
            
            return {
                "type": "stock_analysis",
                "symbol": symbol,
                "data": stock_data,
                "explanation": explanation
            }
        except Exception as e:
            print(f"Error getting stock data: {str(e)}")
            return {"type": "text", "content": f"I had trouble retrieving data for {symbol}. Error: {str(e)}"}
    
    # Default response for other types of messages
    return {"type": "text", "content": "I can help you find information about companies and analyze stocks. Try asking about a specific company like 'Tell me about Apple' or 'How is TSLA stock performing?'"}
