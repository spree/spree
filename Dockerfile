# This dockerfile is used to build sandbox image for docker clouds. It's not meant to be used in projects
FROM ruby:2.5.1
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs
RUN mkdir /spree
WORKDIR /spree
ADD . /spree
RUN bundle install
RUN bundle exec rake sandbox
CMD ["sh", "docker-entrypoint.sh"]
