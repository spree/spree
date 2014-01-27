---
title: "Deploying to Shelly Cloud"
section: deployment
---

## Overview

This guide will show you how to deploy the Spree Commerce to
[Shelly Cloud](https://shellycloud.com/). Before we can start
you need to [create an account](https://shellycloud.com/sign_up).
Shelly Cloud is a git-based cloud hosting, so make sure that
your application is under Git version control system.

## Requirements

First you need to install client tool and login to your account

    $ gem install shelly
    $ shelly login

This procedure will upload your SSH public key.

To fill up application requirements you need to just add one gem into
your `Gemfile`

     gem 'rails', '4.0.2'
     
    +gem 'shelly-dependencies'

`shelly-dependencies` gem includes `thin` and `rake` gems. It will
also configure your application to serve static assets and compile
assets on request.

## Creating new cloud

Create new cloud for your application by running `shelly add`.
Just remember to choose PostgreSQL as a database engine.

As you can see the [Cloudfile](https://shellycloud.com/documentation/cloudfile)
appeared. It defines your cloud structure. Now you have to add it
to your git repository and push to `shelly` remote:

    $ git add Cloudfile
    $ git commit -m "Added Cloudfile for Shelly Cloud"
    $ git push shelly master

***
There is no need to configure PostgreSQL credentials, because
Shelly Cloud generates it by default. More information can be
found in [documentation](https://shellycloud.com/documentation/managing_databases).
***

## Importing sample Spree data

You can load sample Spree data by running

    $ shelly rake 'spree_sample:load'

or just

    $ shelly rake 'db:seed'

for loading basic seeds.

***
Shelly Cloud will run `db:setup` task if there is no `db/schema.rb`
file. During the seed task (which is a part of setup), Spree
asks for user login and password. Shelly Cloud is non interactive, so you
need to set `AUTO_ACCEPT` flag as an environment variable. You can set it
using [dotenv](https://shellycloud.com/documentation/environment_variables#dotenv)
gem.
***

## Storing files

Shelly Cloud provides
[local file storage](https://shellycloud.com/documentation/storing_files)
which is shared between all virtual servers.
The only thing that you have to do is to create
`config/deploy/shelly/before_restart`
[hook](https://shellycloud.com/documentation/deployment_hooks) with the
following content:

    set -e

    mkdir -p disk/spree
    ln -s ../disk/spree public/spree

## Pushing to Shelly Cloud

Shelly Cloud is a git-based cloud hosting, so all you need to do is to run

    $ git push shelly master

for push and deploy your application. Now you can start your cloud by
running

    $ shelly start

***
You do not have to run migrations manually. Shelly Cloud runs
`rake db:migrate` task on each deployment.
***
