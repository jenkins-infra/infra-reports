FROM debian:stable-slim

RUN apt-get update
RUN apt-get install -y wget curl

COPY user-report.sh /

ENTRYPOINT ["sh", "/user-report.sh"]
