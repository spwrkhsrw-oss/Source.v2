FROM python:3.9-slim

# Install dependencies
RUN apt-get update && apt-get install -y wget unzip && rm -rf /var/lib/apt/lists/*

# Install Python requirements
COPY requirements.txt .
RUN pip install -r requirements.txt

# Download and install Lune
RUN wget https://github.com/lune-org/lune/releases/download/v0.10.4/lune-0.10.4-linux-x86_64.zip -O lune.zip \
    && unzip lune.zip \
    && chmod +x lune \
    && mv lune /usr/local/bin/lune \
    && rm lune.zip

# Copy source code
COPY src/ src/

# Set environment variable for unbuffered output
ENV PYTHONUNBUFFERED=1

# Run the bot
CMD ["python", "src/bot.py"]
