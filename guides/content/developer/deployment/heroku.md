---
title: "Deploying to Heroku"
section: deployment
---

## Overview

This article will walk you through configuring and deploying your Spree
application to Heroku.

This guide assumes that your application is deploy-ready and that you have a
Heroku application already created on the Heroku stack for this application. If
you don't have a Heroku app already, follow [this
guide](https://devcenter.heroku.com/articles/creating-apps).

***
Heroku's tools assume that your application is version controlled by Git, as
Git is used to push the code to Heroku.
***

## Configuring your application

### Specify Ruby version

You should speficy the exact ruby version you want to run in your Gemfile:

```ruby
ruby '2.0.0'
```

Keep in mind that Spree 2.0.0 requires a version of Ruby greater than or equal to Ruby 1.9.3.
See [Heroku Ruby support page](https://devcenter.heroku.com/articles/ruby-support#build-behavior)
for details on build behaviour related to Ruby versions.

### Add Heroku 12 Factor Gem

Add the [Heroku 12 Factor gem](https://github.com/heroku/rails_12factor) to your Gemfile:

```ruby
gem 'rails_12factor', group: :production
```

This will enable your application to serve static assets and direct logging to stdout.

### Rails 4

As of rails 4 things got a bit more complicated to deploy spree apps on heroku.
Spree versions up to 2.2.0 require a db connection on initialization. Heroku
won't allow the db connection though the first time you deploy the app, probably
because it doesn't know which database to connect to yet.

A possible work around for this is to uninstall spree from your rails app,
deploy it to heroku and only then install spree again, e.g. by reverting
your previous commits, so that you get a successful deploy.

Also look into this [github thread](https://github.com/spree/spree/issues/3749#issuecomment-30987342)
and all related for further info on how you could accomplish a successful
heroku deploy.

Fortunately a lot of work has been done so that Spree 2.3 doesn't touch db
on initialization. This issue about [preferences on initialization](https://github.com/spree/spree/issues/3833)
contains most of the context related.

### Asset Pipeline Rails 3

When deploying to Heroku by default Rails will attempt to intialize itself
before the assets are precompiled. This step will fail because the application
will attempt to establish a database connection, which Heroku will not have set
up yet.

To work around this issue, put this line underneath the other `config.assets`
lines inside `config/application.rb`:

```ruby
config.assets.initialize_on_precompile = false
```

The assets for your application will still be precompiled, it's just that Rails
won't be intialized during this process.

***

### Paperclip image quality issues
Heroku currently defaults to a surprisingly old version of ImageMagick (6.5 as of March 2014) which can cause problems.  Aside from the fact that 6.5 is missing some of the newer command line arguments that Paperclip can invoke, its [image conversion quality is noticeably inferior](http://i.imgur.com/dqeNdlW.png) to that of the current release.  You can easily work around this by [using a Heroku buildpack to provide the latest ImageMagick release](https://github.com/spree/spree/pull/3104#issuecomment-36977413).  You may have to `:reprocess!` your images after upgrading ImageMagick.

### S3 Support

Because Heroku's filesystem is readonly, you will need to configure Spree to
upload the assets to an off-site server, such as S3. If you don't have an S3
account already, you can [set one up here](http://aws.amazon.com/s3/)

This guide will assume that you have an S3 account already, along with a bucket
under that account for your files to go into, and that you have generated the
access key and secret for your S3 account.

To configure Spree to upload images to S3, please refer to the following [documentation](http://guides.spreecommerce.com/developer/s3_storage.html)


## Pushing to Heroku

Once you have configured the above settings, you can push your Spree application
to Heroku:

```bash
$ git push heroku master
```

Once your application is on Heroku, you will need to set up the schema by
running this command:

```bash
$ heroku run rake db:migrate
```

You may then wish to set up an admin user as well which can be done by loading
the rails console:

```bash
$ heroku run rails console
```

And then running this code:

```ruby
user = Spree::User.create!(:email => "you@example.com", :password => "yourpassword")
user.spree_roles.create!(:name => "admin")
```

Exit out of the console and then attempt to sign in to your application to
verify these credentials.

## SSL Support

For information about SSL support with Heroku, please read their [SSL Guide](https://devcenter.heroku.com/articles/ssl).
