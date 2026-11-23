FROM python:3.13-alpine

WORKDIR /app
COPY index.html .

CMD ["python", "-m", "http.server", "8000", "--bind", "127.0.0.1"]
