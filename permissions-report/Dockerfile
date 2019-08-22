FROM ruby:2.5-slim

RUN gem install graphql-client httparty

COPY permissions-report.rb /

ENTRYPOINT ["ruby", "/permissions-report.rb"]
