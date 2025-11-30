# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.191.1/containers/ruby/.devcontainer/base.Dockerfile

# [Choice] Ruby version: 3.4, 3.3, 3.2
ARG VARIANT="3.4"
FROM ghcr.io/rails/devcontainer/images/ruby:${VARIANT}

RUN sudo apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && sudo apt-get -y install --no-install-recommends \
        libvips-dev sqlite3
