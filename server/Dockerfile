FROM ruby:3.4.4-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    postgresql-client \
    libpq-dev \
    libyaml-dev \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Spree gems from this fork — source of truth for SPREE_PATH below
COPY spree/ /spree/

# server/ is gitignored and normally cloned fresh per environment (see
# bin/render-build.sh) — do the same here instead of relying on a committed
# host app, so the image always builds against the fork's engine gems.
RUN git clone --depth 1 https://github.com/spree/spree-starter.git /app/server \
    && echo "3.4.4" > /app/server/.ruby-version \
    && printf 'SPREE_PATH=/spree\n' > /app/server/.env

WORKDIR /app/server

ENV SPREE_PATH=/spree
ENV BUNDLE_IGNORE_CONFIG=1
ENV SECRET_KEY_BASE_DUMMY=1

RUN bundle lock && bundle install --without development test && bundle check

RUN bundle exec rails assets:precompile

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
