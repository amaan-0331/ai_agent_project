# Use an official Python runtime as a parent image.
FROM python:3.9-slim

# Set the working directory in the container.
WORKDIR /app

# Copy the current directory contents into the container.
COPY . /app

# Install any needed packages specified in requirements.txt.
RUN pip install --upgrade pip && pip install -r requirements.txt

# Download spaCy model
RUN python -m spacy download en_core_web_sm

# Expose port 8080 to the outside world.
EXPOSE 8080

# Define environment variable for Flask app.
ENV PORT 8080

# Run the app with gunicorn.
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "app:app"]
