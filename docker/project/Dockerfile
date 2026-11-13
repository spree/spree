# syntax=docker/dockerfile:1

# Builds this project's production image on the Spree base image. The base
# holds Ruby, Node and the system libraries; `spree-image-build` installs the
# gems and builds the app and the dashboards. Rebuilding picks up the base's
# security fixes. To pin a build, set SPREE_BASE to a dated tag such as
# ghcr.io/spree/spree-base:6.1-202611160323.
#
# The build context is the project root of a create-spree-app project, or the
# Rails app itself in a bare clone of spree-starter.
ARG SPREE_BASE=ghcr.io/spree/spree-base:6.1

FROM ${SPREE_BASE}-build AS build

# Gems first, in their own layer: a code change does not reinstall them.
# The Gemfile sits at the context root, or under server/ (backend/ in older
# projects). `[s]erver` is a wildcard, so a directory that is absent is skipped
# where a plain `server/` would fail the build.
COPY --chown=rails:rails Gemfile* .ruby-version* [s]erver/Gemfile* [s]erver/.ruby-version* [b]ackend/Gemfile* [b]ackend/.ruby-version* ./
RUN spree-image-build gems

COPY . /src
RUN spree-image-build app /src

FROM ${SPREE_BASE}

COPY --chown=rails:rails --from=build /usr/local/bundle /usr/local/bundle
COPY --chown=rails:rails --from=build /rails /rails
