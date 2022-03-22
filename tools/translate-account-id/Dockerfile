FROM python:3.8-alpine
RUN pip install --no-cache-dir base58~=2.1
COPY ./translate-account-id.py /docker-entrypoint.py
ENTRYPOINT ["/docker-entrypoint.py"]
