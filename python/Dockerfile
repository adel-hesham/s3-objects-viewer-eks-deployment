FROM python:3.12-alpine

WORKDIR /app

RUN pip install --no-cache-dir flask boto3

COPY app.py    .
COPY static/   static/

EXPOSE 80

CMD ["python", "app.py"]
