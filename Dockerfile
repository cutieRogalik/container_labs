FROM python:3.11-slim


LABEL maintainer="lishchuk@lab.local"
LABEL version="1.0"

WORKDIR /app

COPY requirements.txt .

RUN pip install -r requirements.txt

COPY app/ ./app/

EXPOSE 5449

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "5449"]
