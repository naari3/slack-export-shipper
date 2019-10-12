FROM ruby:2.6-slim

RUN apt update && apt install --no-install-recommends -y git build-essential \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
Add . /app
RUN bundle install

ENTRYPOINT ["bundle", "exec", "slack_gijiroku"]
CMD ["--help"]
