FROM ruby:2.4-slim

RUN gem install graphql-client httparty

COPY permissions-report.rb /

ENTRYPOINT ["ruby", "/permissions-report.rb"]
