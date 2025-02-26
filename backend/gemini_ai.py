import os
import google.generativeai as genai

# Set up the API key
GOOGLE_API_KEY = os.environ.get("GOOGLE_API_KEY")
if not GOOGLE_API_KEY:
    raise ValueError("The environment variable GOOGLE_API_KEY is not set.")

# Configure the generative AI with your API key
genai.configure(api_key=GOOGLE_API_KEY)

def generate_stock_explanation(stock_data):
    # Initialize the Gemini model
    model = genai.GenerativeModel('gemini-2.0-pro-exp-02-05')

    # Create a prompt for the model
    prompt = f"""
    Please analyze the following stock data and provide a clear explanation:
    
    {stock_data}
    
    Include insights about:
    1. Recent price movements and trends
    2. Volume analysis and how it relates to price action
    3. Notable patterns or potential support/resistance levels
    4. Key indicators for this stock based on the data
    5. A balanced perspective on potential risks and opportunities
    
    Format your response in a way that would be helpful for an investor to understand the current state of this stock.
    """
    
    # Generate content with Gemini
    response = model.generate_content(prompt)
    
    return response.text