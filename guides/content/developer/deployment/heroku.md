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

### Asset Pipeline

***
If you're on Rails 4 or greater. There's no longer
a `initialize_on_precompile` config option because you should be able to run
`assets:precompile` without a database connection. See Heroku [troubleshooting
page for details](https://devcenter.heroku.com/articles/rails-asset-pipeline#troubleshooting).
Unfortunately Spree still needs to connect to db on startup so you'll have to
enable the [user-env-compile](https://devcenter.heroku.com/articles/labs-user-env-compile)
feature on heroku to run your store.
***

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

### S3 Support

Because Heroku's filesystem is readonly, you will need to configure Spree to
upload the assets to an off-site server, such as S3. If you don't have an S3
account already, you can [set one up here](http://aws.amazon.com/s3/)

This guide will assume that you have an S3 account already, along with a bucket
under that account for your files to go into, and that you have generated the
access key and secret for your S3 account.

To configure Spree to upload images to S3, put these lines into
`config/initializers/spree.rb`:

```ruby
Spree.config do |config|
  config.use_s3 = true
  config.s3_bucket = '<bucket>'
  config.s3_access_key = "<key>"
  config.s3_secret = "<secret>"
end
```

If you're using the Western Europe S3 server, you will need to set two
additional options inside this block:

```ruby
Spree.config do |config|
  ...
  config.attachment_url = ":s3_eu_url"
  config.s3_host_alias = "s3-eu-west-1.amazonaws.com"
end
```

And additionally you will need to tell paperclip how to construct the URLs for
your images by placing this code outside the +config+ block inside
`config/initializers/spree.rb`:

```ruby
Paperclip.interpolates(:s3_eu_url) do |attachment, style|
"#{attachment.s3_protocol}://#{Spree::Config[:s3_host_alias]}/#{attachment.bucket_name}/#{attachment.path(style).gsub(%r{^/},"")}"
end
```

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
