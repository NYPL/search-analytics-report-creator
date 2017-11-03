FROM ruby:2.4.2
WORKDIR /app
ADD . /app
RUN bundle install
ENTRYPOINT ["/bin/bash", "/app/test.sh"]