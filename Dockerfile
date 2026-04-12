FROM python:3.11-slim

WORKDIR /app

COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/ ./backend/

# Explicitly declare port 8000 to lock Railway's proxy to 8000
EXPOSE 8000

# Explicitly ignore Railway's dynamic $PORT and force uvicorn to 8000
CMD ["sh", "-c", "cd backend && uvicorn app:app --host 0.0.0.0 --port 8000"]
