FROM ruby:2.3-slim

RUN gem install graphql-client

COPY permissions-report.rb /

ENTRYPOINT ["ruby", "/permissions-report.rb"]
