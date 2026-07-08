FROM ruby:3.4.4-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    postgresql-client \
    libpq-dev \
    libyaml-dev \
    zlib1g-dev \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# Spree gems from this fork. SPREE_PATH points at /workspace (not /workspace/spree)
# because spree-starter's Gemfile resolves gems as "#{SPREE_PATH}/spree/core" etc,
# mirroring bin/render-build.sh where SPREE_PATH is the monorepo root.
COPY spree/ /workspace/spree/

# server/ is gitignored and normally cloned fresh per environment (see
# bin/render-build.sh) — do the same here instead of relying on a committed
# host app, so the image always builds against the fork's engine gems.
RUN git clone --depth 1 https://github.com/spree/spree-starter.git /workspace/server \
    && echo "3.4.4" > /workspace/server/.ruby-version \
    && printf 'SPREE_PATH=/workspace\n' > /workspace/server/.env

WORKDIR /workspace/server

ENV SPREE_PATH=/workspace
ENV BUNDLE_IGNORE_CONFIG=1
ENV SECRET_KEY_BASE_DUMMY=1

RUN bundle lock && bundle install --without development test

# Assets precompilation happens on VPS after deployment (not in Docker build)
# to avoid bundler gem resolution issues with excluded groups

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
