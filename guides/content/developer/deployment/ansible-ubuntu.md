---
title: "Deploying to Ubuntu using Ansible"
section: deployment
---

## Overview

Along with the [Manual Ubuntu Deployment Guide](/developer/manual-ubuntu.html), Spree can also be set up using [Ansible](http://ansibleworks.com). From Ansible's website:

> Ansible is a radically simple IT orchestration engine that makes your applications and systems easier to deploy. Avoid writing scripts or custom code to deploy and update your applications— automate in a language that approaches plain English, using SSH, with no agents to install on remote systems.

To set up a server using Ansible, we're going to use what's referred to as a [playbook](http://www.ansibleworks.com/docs/playbooks.html). This particular playbook is available from [radar/ansible-rails-app](https://github.com/radar/ansible-rails-app) on GitHub and will install the following things:

- Ruby 2.1
- PostgreSQL 9.3
- nginx
- Puma (jungle)
- ImageMagick

With the playbook, you may wish to customize it to install a different version of Ruby, a different database system, Apache rather than nginx or unicorn instead of puma. It's extremely flexible. For this guide however, we will just cover the things that the default playbook does.

## Set up Ansible

Ansible works using a *control machine*, which just needs to be a system that has Python 2.6 installed. To set up Ansible on the control machine, follow [this guide](http://www.ansibleworks.com/docs/intro_installation.html#id11).

## Playbook introduction

Before we can run the playbook, we'll need to set up where the server is located. Rename the `hosts.example` file within the `ansible-rails-app` repository to `hosts` and put in the location of your server.

The playbook has this setup within `ruby-webapp.yml`:

```yaml
- hosts: all
  user: root
  vars_files:
    - vars/defaults.yml

  roles:
    - webserver
    - database
```

This tells Ansible that on all hosts specified within the `hosts` file, we want to use the user `root` and the variables from `vars/defaults.yml`. On these hosts, we want to give them the roles of `webserver` and `database`. Since we're only setting up one host here, that is a good setup. If we wanted the server and the database to be on separate hosts, then we would need to configure it as such within the playbook.

***
If your server's default user is not `root`, then remember to change that here.
***

In `vars/defaults.yml`, we set up some variables that our playbook will reference later on:

```yaml
## webapp

webserver_name: spree.example.com
deploy_directory: /data/spree
app_name: spree

## stolen from https://github.com/jgrowl/ansible-playbook-ruby-from-src
rubyTmpDir: /usr/local/src
rubyUrl: http://cache.ruby-lang.org/pub/ruby/2.1/ruby-2.1.0.tar.gz
rubyCompressedFile: ruby-2.1.0.tar.gz
rubyName: ruby-2.1.0
tmpRubyPath: {{rubyTmpDir}}/{{rubyName}}
```

Before we can run the playbook, we'll need to set up key-based authentication on the server so we are not asked for our password. To do this, we can run this command:

    scp ~/.ssh/id_rsa.pub root@<server>:~/.ssh/authorized_keys

To ensure that this worked, try connecting to the server:

    ssh root@<server>

If you are not prompted for your password, then key-based authentication is setup.

You will need to also set up the deployment key for the deploy user. This is done in `roles/webserver/tasks/deploy.yml` with this line:

```yaml
- authorized_key: user=deploy key="{{ lookup('file', '/Users/example/.ssh/id_rsa.pub') }}"
```

Change this path to point to the path on your system where your public key resides.

## Running the playbook

Within the repository, there is a directory called "roles" which contains two sub-directories for the roles that are defined within `ruby-webapp.yml`. In each of these sub-directories there is another directory called `tasks` which defines the tasks that should be run for these roles. The `main.yml` within these directories lists the tasks that need to be run.

Within `roles/webserver/tasks/main.yml`, we have this:

```yaml
- include: ruby.yml tags=ruby
- include: deploy.yml tags=deploy
- include: puma.yml tags=puma
- include: nginx.yml tags=nginx
```

Within `roles/database/tasks.main.yml`, we have this:

```yaml
- include: postgresql.yml tags=postgresql
```

We can run the playbook with this command:

    ansible-playbook ruby-webapp.yml -t ruby,deploy,postgresql,nginx

The `-t` option tells Ansible that we want to run only the tasks tagged with those tags, in that order.

### Deploy tasks

Tasks with the `deploy` tag will be run first, and those tasks live within `roles/webserver/tasks/deploy.yml`. These tasks perform the following actions:

* Updates apt-get to ensure latest packages are available
* Installs dependencies for Ruby
* Installs application-specific dependencies
* Installs Ruby from ruby-lang.org
* Creates a deployment user called "deploy"
* Copies over the public key so that key-based authentication for "deploy" works
* Creates the deployment directory
* Makes the shared directories for Capistrano to deploy into later on
* Inserts the database.yml to be used for the application
* Installs the Bundler gem

These are all the basic steps to setup a Ruby installation on the server, as well as a directory on the server to deploy the application into.

### PostgreSQL tasks

The next tag is the `postgresql` tag, which will run the tasks within `roles/database/tasks/postgresql.yml`. These tasks do these actions:

* Installs PostgreSQL dependencies
* Installs PostgreSQL 9.3 from Postgresql.org's own apt repository
* Sets up a secure `pg_hba.conf` using a template
* Sets up `postgresql.conf` using a template
* Ensures the PostgreSQL service has started
* Creates the PostgreSQL user for the application
* Creates the PostgreSQL database for the application

### nginx tasks

The final tag that we provided was the `nginx` tag, which will run the tasks listed within `roles/webserver/tasks/nginx.yml`. These tasks do these things:

* Installs nginx
* Removes the default nginx app configuration
* Sets up the application's configuration using a template
* Ensures the nginx service has been started.

## Using Capistrano to deploy

When the playbook finishes, Ruby, PostgreSQL and nginx will be installed and from this point we can then deploy the application to the server using Capistrano. We can set up Capistrano within our application by running this command:

    cap install

This sets up the basic Capistrano files within the application that we need to deploy. The `ansible-rails-app` repository contains a `deploy.rb` which you can use as a starting point within your application.

Before you do anything else, uncomment these three lines in `Capfile`:

    require 'capistrano/bundler'
    require 'capistrano/rails/assets'
    require 'capistrano/rails/migrations'

You will also need to add these gems to the Gemfile:

    group :development do
      gem 'capistrano', '~> 3.0'
      gem 'capistrano-bundler', '1.1.1'
      gem 'capistrano-rails', '1.1.0'
    end

Then configure `config/deploy/production.rb` to point to the correct server, and finally run this command to deploy:

    bundle exec cap production deploy

One of the final steps, the one that restarts Puma, will probably fail because we have not yet set up Puma on the server. We can rectify this by setting that up on the server using Ansible within the `ansible-rails-app` directory:

    ansible-playbook ruby-webapp.yml -t puma

The tasks performed are as follows:

* Sets up a puma-manager to manage the Puma services
* Copies configuration for puma to the server
* Adds puma init script
* Adds config/puma/production.rb to the application's shared directory
* Creates shared/tmp/sockets within the deploy directory
* Ensures the puma-manager service is started.

Running the deploy command again will now succeed:

    bundle exec cap production deploy

## Seeding data

You can also choose to seed the Spree store with some sample data by running this command:

    bundle exec cap production spree_sample:load
