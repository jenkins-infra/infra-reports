FROM ruby:2.6.5-alpine3.10

RUN gem install graphql-client httparty

COPY fork-report.rb /

ENTRYPOINT ["ruby", "/fork-report.rb"]
