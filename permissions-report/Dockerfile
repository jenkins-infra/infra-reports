FROM ruby:2.6.5-alpine3.10

RUN gem install graphql-client httparty

COPY permissions-report.rb /

ENTRYPOINT ["ruby", "/permissions-report.rb"]
