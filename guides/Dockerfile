FROM rlister/ruby:2.1.5
MAINTAINER Ric Lister <ric@spreecommerce.com>

RUN DEBIAN_FRONTEND=noninteractive \
    apt-get update && \
    apt-get install -y \
    nginx-light

WORKDIR /guides

## cache the bundle
ADD Gemfile* /guides/
RUN bundle install --without development test

## build pages
ADD . /guides
RUN bundle exec nanoc compile

## install in nginx root
WORKDIR /var/www
RUN rm -rf html && \
    mv /guides/output html && \
    rm -rf /guides && \
    echo "\ndaemon off;" >> /etc/nginx/nginx.conf && \
    echo "\nerror_log /dev/stdout info;" >> /etc/nginx/nginx.conf

EXPOSE 80
CMD [ "nginx" ]
