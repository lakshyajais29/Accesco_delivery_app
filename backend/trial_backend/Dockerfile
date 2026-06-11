FROM python:3.12-slim

WORKDIR /srv

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy everything from the current directory directly into /srv
COPY . .

EXPOSE 8000

# Run main.py directly since it's not inside an 'app' folder
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]