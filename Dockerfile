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

# Copy spree gems from this fork
COPY spree/ /workspace/spree/

# Clone spree-starter fresh into /workspace/server
RUN git clone --depth 1 https://github.com/spree/spree-starter.git /workspace/server \
    && echo "3.4.4" > /workspace/server/.ruby-version

WORKDIR /workspace/server

# Set SPREE_PATH so bundler uses our fork's gems
ENV SPREE_PATH=/workspace
ENV BUNDLE_IGNORE_CONFIG=1
ENV SECRET_KEY_BASE_DUMMY=1

# Install gems from this fork (not RubyGems)
RUN bundle install

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
