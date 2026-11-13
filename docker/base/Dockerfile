# syntax=docker/dockerfile:1

# The Spree base image: the runtime every Spree production image ends on, and a
# build variant projects build and develop in. Neither holds gems, so one build
# serves every patch release of a Spree line. See docker/README.md.
#
#   docker build docker/base --target runtime -t ghcr.io/spree/spree-base:6.1
#   docker build docker/base --target build   -t ghcr.io/spree/spree-base:6.1-build

ARG RUBY_VERSION=4.0
ARG NODE_VERSION=24

# Node is copied from the official image of the same Debian release rather
# than installed from a package repository: one binary, no extra apt source.
FROM docker.io/library/node:${NODE_VERSION}-trixie-slim AS node

FROM docker.io/library/ruby:${RUBY_VERSION}-slim-trixie AS runtime

ARG SPREE_LINE
LABEL org.opencontainers.image.source="https://github.com/spree/spree" \
  org.opencontainers.image.description="Spree base image: Ruby, Node and the system libraries a Spree app runs on"

WORKDIR /rails

# No postgresql-client: the pg gem vendors its own libpq, and Debian's client
# drags in about 70MB of perl and gnupg. The build variant adds it for psql.
RUN apt-get update -qq && \
  apt-get install --no-install-recommends -y curl libjemalloc2 libvips && \
  ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so && \
  rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY --from=node /usr/local/bin/node /usr/local/bin/node

ENV RAILS_ENV="production" \
  BUNDLE_DEPLOYMENT="1" \
  BUNDLE_PATH="/usr/local/bundle" \
  BUNDLE_WITHOUT="development:test" \
  LD_PRELOAD="/usr/local/lib/libjemalloc.so" \
  SPREE_BASE_LINE="${SPREE_LINE}" \
  SPREE_DASHBOARD_DIST_PATH="/rails/dashboard" \
  SPREE_SELLER_PANEL_DIST_PATH="/rails/seller-dashboard"

COPY --chmod=755 bin/spree-entrypoint /usr/local/bin/spree-entrypoint

RUN groupadd --system --gid 1000 rails && \
  useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
  chown rails:rails /rails
USER 1000:1000

ENTRYPOINT ["spree-entrypoint"]
EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]

FROM runtime AS build

USER root

RUN apt-get update -qq && \
  apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config postgresql-client zlib1g-dev && \
  rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
  ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx && \
  ln -s ../lib/node_modules/corepack/dist/corepack.js /usr/local/bin/corepack && \
  corepack enable pnpm

# The CLI release line the stock dashboard and seller panel are taken from
# when a project has no apps/dashboard or apps/seller-dashboard of its own.
ENV SPREE_CLI_VERSION="^3.0.0" \
  COREPACK_ENABLE_DOWNLOAD_PROMPT="0"

COPY --chmod=755 bin/spree-image-build /usr/local/bin/spree-image-build

# Owned by the app user so a build, and the volumes a development container
# mounts over these paths, are writable without root.
RUN mkdir -p /rails/tmp /rails/storage && \
  chown -R rails:rails /rails "${BUNDLE_PATH}"
USER 1000:1000
