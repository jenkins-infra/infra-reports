FROM ruby:3.1.0-alpine

RUN gem install graphql-client httparty

COPY permissions-report.rb /

ENTRYPOINT ["ruby", "/permissions-report.rb"]
