FROM ruby:3.1.0-alpine

RUN gem install graphql-client httparty

COPY fork-report.rb /

ENTRYPOINT ["ruby", "/fork-report.rb"]
