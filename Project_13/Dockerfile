FROM python:3.13-alpine

WORKDIR /app
COPY index.html .

EXPOSE 8080
CMD ["python", "-m", "http.server", "8080", "--bind", "0.0.0.0"]
