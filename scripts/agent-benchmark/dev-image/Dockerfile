# syntax=docker/dockerfile:1
# A stand-in for the starter's `dev` image, for machines that cannot reach the
# Debian mirrors server/Dockerfile installs packages from. It is the prebuilt
# Spree image plus the Gemfile's development and test gems, compiled in the
# full Ruby image (same Ruby, same Debian release). Build it from a scaffolded
# project's server/ directory:
#
#   docker build -t spree-bench-dev -f scripts/agent-benchmark/dev-image/Dockerfile <project>/server
#
# Behind a TLS-intercepting proxy, pass its CA as a secret:
#   --secret id=ca,src=/path/to/ca.crt --network host --build-arg HTTPS_PROXY
#
# Then run the benchmark with --dev-image spree-bench-dev.
ARG SPREE_IMAGE=ghcr.io/spree/spree:latest
ARG RUBY_IMAGE=ruby:4.0.9

FROM ${SPREE_IMAGE} AS prebuilt

FROM ${RUBY_IMAGE} AS gems
ENV BUNDLE_PATH=/usr/local/bundle BUNDLE_WITHOUT="" BUNDLE_DEPLOYMENT=0
COPY --from=prebuilt /usr/local/bundle /usr/local/bundle
WORKDIR /rails
COPY Gemfile Gemfile.lock .ruby-version ./
RUN --mount=type=secret,id=ca,required=false \
  if [ -f /run/secrets/ca ]; then export SSL_CERT_FILE=/run/secrets/ca BUNDLE_SSL_CA_CERT=/run/secrets/ca; fi && \
  bundle install && rm -rf /usr/local/bundle/ruby/*/cache

FROM ${SPREE_IMAGE}
USER root
COPY --from=gems /usr/local/bundle /usr/local/bundle
ENV RAILS_ENV=development BUNDLE_DEPLOYMENT=0 BUNDLE_WITHOUT=""
# Runs as root, unlike the starter's dev image: the bind-mounted server/ then
# stays writable whichever user owns it on the host (CI and sandboxes often
# run as root, the starter's image as UID 1000).
ENTRYPOINT []
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
