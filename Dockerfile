FROM dkubb/alpine-ruby
MAINTAINER Dan Kubb <dan@bloomcrush.com>

ENV TZ=utc \
  RAILS_ENV=test \
  RACK_ENV=test \
  NEW_RELIC_ENV=test \
  PGDATA=/var/db/postgresql/data \
  DB=postgres

COPY config/docker/etc /etc/

RUN echo '@testing https://s3.amazonaws.com/alpine-packages/testing' >> /etc/apk/repositories \
  && apk add --update-cache \
    imagemagick=6.9.2.8-r0 \
    libxml2-dev=2.9.3-r0 \
    libxslt-dev=1.1.28-r2 \
    ncurses=6.0-r7 \
    nodejs=4.2.5-r0 \
    phantomjs@testing=1.9.8-r0 \
    postgresql-dev=9.5.0-r0

# Initialize database
RUN setup-directories.sh postgres rw "$(dirname "$PGDATA")" "$PGDATA" \
  && sudo --preserve-env -u postgres pg_ctl initdb

COPY shared                                           /opt/spree/shared/
COPY core/Gemfile     core/spree_core.gemspec         /opt/spree/core/
COPY api/Gemfile      api/spree_api.gemspec           /opt/spree/api/
COPY backend/Gemfile  backend/spree_backend.gemspec   /opt/spree/backend/
COPY frontend/Gemfile frontend/spree_frontend.gemspec /opt/spree/frontend/

WORKDIR /opt/spree

# Install gem dependencies
RUN set -e \
  && bundle config --delete frozen without \
  && for dir in api backend core frontend; do \
    (cd $dir && until timeout -t 180 bundle; do :; done) \
  done

COPY . /opt/spree/

# Setup test app and database
RUN set -e \
  && sudo --preserve-env -u postgres pg_ctl start -w \
  && for dir in api backend core frontend; do (cd $dir && bundle exec rake test_app); done \
  && sudo --preserve-env -u postgres pg_ctl stop
