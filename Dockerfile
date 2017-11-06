FROM ruby:2.4.2
WORKDIR /app
ADD . /app
RUN bundle install --without development
ENTRYPOINT ["/bin/bash", "/app/run-reports.sh"]
