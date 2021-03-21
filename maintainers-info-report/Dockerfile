FROM debian:stable-slim

RUN apt-get update
RUN apt-get install -y wget curl

COPY maintainers-info-report.sh /
RUN chmod +x /maintainers-info-report.sh

ENTRYPOINT [ "/maintainers-info-report.sh" ]
