FROM debian:stable-slim

RUN apt-get update
RUN apt-get install -y wget curl

COPY user-report.sh /
RUN chmod +x /user-report.sh

ENTRYPOINT [ "/user-report.sh" ]
