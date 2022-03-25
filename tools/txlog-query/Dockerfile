ARG python_image_tag="3.8-slim-buster"
FROM python:${python_image_tag}
# Install system dependencies for Python dependency 'psycopg2'.
RUN apt-get update && apt-get install -y gcc libpq-dev && rm -rf /var/lib/apt/lists/*
# Add user 'docker' for running as non-root.
RUN adduser --system docker
USER docker
WORKDIR /app
# Install Python dependencies.
COPY ./requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt
# Copy application files.
COPY . .
#ENV PYTHONPATH=/app
ENTRYPOINT ["./main.py"]
