FROM ruby:3.1.1-alpine3.15

RUN apk add openssl-dev openssl build-base

RUN gem install graphql-client httparty jwt time openssl base64

COPY permissions-report.rb /

ENTRYPOINT ["ruby", "/permissions-report.rb"]
