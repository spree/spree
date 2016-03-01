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
    imagemagick=6.9.3.6-r0 \
    libxml2-dev=2.9.3-r0 \
    libxslt-dev=1.1.28-r2 \
    ncurses=6.0-r7 \
    nodejs=4.3.1-r0 \
    phantomjs@testing=1.9.8-r0 \
    postgresql-dev=9.5.1-r0

# Setup buildkite user
RUN adduser -D -g '' -u 1000 buildkite \
  && chmod 1700 ~buildkite

# Allow buildkite to access the docker socket
RUN addgroup buildkite users

# Allow buildkite user to use sudo for pg_ctl
RUN echo 'buildkite ALL=(postgres) NOPASSWD: /usr/bin/pg_ctl' \
  | (EDITOR='tee -a' visudo)

# Setup postgresql data directory
RUN setup-directories.sh postgres rw "$(dirname "$PGDATA")" "$PGDATA"

USER postgres
WORKDIR $PGDATA

# Setup test database
RUN pg_ctl initdb -o '--auth-host=reject --auth-local=trust --encoding=UTF-8'

COPY shared                                           /opt/spree/shared/
COPY core/Gemfile     core/spree_core.gemspec         /opt/spree/core/
COPY api/Gemfile      api/spree_api.gemspec           /opt/spree/api/
COPY backend/Gemfile  backend/spree_backend.gemspec   /opt/spree/backend/
COPY frontend/Gemfile frontend/spree_frontend.gemspec /opt/spree/frontend/

USER root
RUN chown -R buildkite: /opt

USER buildkite
WORKDIR /opt/spree

# Install gem dependencies
RUN bundle config --global build.nokogiri '--use-system-libraries' \
  && bundle config --global disable_shared_gems '1' \
  && bundle config --global jobs '8' \
  && bundle config --global path "$(pwd)/vendor/bundle" \
  && for dir in api backend core frontend; do (cd $dir && until timeout -t 180 bundle; do :; done) done

COPY . /opt/spree/

USER root
RUN chown -R buildkite: /opt/spree

USER buildkite

# Setup test app and database
RUN set -e \
  && (cd / && sudo --user postgres pg_ctl start -w --pgdata "$PGDATA" > /dev/null) \
  && for dir in api backend core frontend; do (cd $dir && bundle exec rake test_app); done \
  && (cd / && sudo --user postgres pg_ctl stop --pgdata "$PGDATA" > /dev/null)
