## create a container running the basic sandbox rails application
## as described in the README
##
## basic usage:
##   docker build -t spree_sandbox .
##   docker run -it -p 3000:3000 spree_sandbox

FROM rlister/ruby:2.1.2

MAINTAINER Ric Lister, rlister@gmail.com

## this is a horrific set of deps since we need all the databases to bundle
RUN apt-get update && apt-get install -yq \
    git \
    postgresql libpq-dev \
    mysql-server libmysqlclient-dev \
    sqlite3 libsqlite3-dev \
    nodejs

## keep the size of the image down
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

## :TODO: use this is a base for non-cache-busting bundle install
# WORKDIR /tmp
# ADD ./Gemfile /tmp/
# ADD ./common_spree_dependencies.rb /tmp/
# ADD ./spree.gemspec /tmp/
# ADD ./SPREE_VERSION /tmp/
# ADD ./Gemfile.lock /tmp/
# ADD ./api /tmp/
# ADD ./backend /tmp/
# ADD ./cmd /tmp/
# ADD ./frontend /tmp/
# ADD ./sample /tmp/

## install full local repo
WORKDIR /app
ADD ./ /app

RUN bundle install

## create a sandbox application
RUN bundle exec rake sandbox
WORKDIR /app/sandbox

EXPOSE 3000

## bundle exec all the things
ENTRYPOINT [ "bin/bundle", "exec" ]
CMD [ "rails", "server" ]
