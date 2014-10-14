# This Dockerfile builds Spree from master in a container and  sets up
# the 'sandbox' test app.
#
# From there you'll be able to run the test suite or a web server.
#
# Basic usage:
# 
#  $ docker build --tag="spree-master-local" .
#  $ docker run -t -i spree-master-local tmux
#
#  (From within the container)
#
#  Rails console:
#    $ bundle exec rails c
#
#  Externally-accessible rails server:
#    $ bundle exec rails s
#
# To rebuild from scratch:
#  $ docker build --no-cache=true --tag="spree-master-local" .
#
# Browser testing:
#  To map container port 3000 to localhost port 3333:
#  $ docker run -t -i -p 127.0.0.1:3333:3000 spree-master-local tmux
#

############################################################
# BASE IMAGE
############################################################

# See https://github.com/phusion/passenger-docker for details on this image. 
FROM phusion/passenger-ruby21:0.9.10

############################################################
# ENVIRONMENT
############################################################

# Set $HOME to /root for preparatory setup
ENV HOME /root

# Use phusion/baseimage-docker's init process.
CMD ["/sbin/my_init"]

# Expose container port 3000 for access from outside of the container
EXPOSE 3000

############################################################
# PACKAGES
############################################################

RUN   apt-get update --fix-missing

# tmux can help simplify interactive work inside the container.
RUN   apt-get -y install tmux

# Base spree requests all three databases for testing.
# DB client gems require the dev packages to compile.
RUN   apt-get -y install postgresql     libpq-dev
RUN   apt-get -y install mysql-server   libmysqlclient-dev
RUN   apt-get -y install sqlite3        libsqlite3-dev

# Clean up APT when done.
RUN   apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


############################################################
# APP + GEMS
############################################################

# Create local gem_home folder (bundler cache defaults to $GEM_HOME)
RUN       mkdir    /home/app/gem_home
ENV       GEM_HOME /home/app/gem_home

# Copy your local git copy of Spree install to container
ADD       ./  /home/app/spree

# Ensure the folders we just created belong to the unprivileged user
RUN       chown -R app:app /home/app

USER      app
WORKDIR   /home/app/spree

# Local artifacts for simpler permissions
RUN       bundle install
RUN       bundle exec rake sandbox
WORKDIR   /home/app/spree/sandbox
RUN       bundle install

# Switch back to app user's $HOME for interactive work
ENV       HOME /home/app
