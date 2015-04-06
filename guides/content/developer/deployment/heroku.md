---
title: "Deploying to Heroku"
section: deployment
---


!!!
Mention of 3rd party products does not imply endorsement.
!!!

## Overview

This article will walk you through configuring, and deploying your Spree
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

### General Bloat and Efficiency Considerations

Heroku has specific [platform-imposed limitations](https://devcenter.heroku.com/articles/limits). The most important limitation to consider is that all web requests must be finished within 30 seconds. You should have really good exception tooling (HoneyBadger, Rollbar, etc) in place as well as a performance tool (like NewRelic) to monitor your site as it grows.

Hitting the request timeout is inherently problematic for your app. If your app is in the middle of an operation while it is interrupted, it could leave your data in an incomplete state that could create additional bugs for the user. If you don't have [Rack-Timeout](https://github.com/heroku/rack-timeout) installed, you may alleviate some of that problem by letting the dyno finish the request in the background even though the Heroku Router has already terminated the response. If you do have Rack Timeout installed, you probably will have it set to just below the 30 second timeout (that way you can see those timeouts in the exception tool of your choice). However, this has the added risk of leaving your cart in a bad state.

Some factors that can cause timeouts are:
- Running on the 1X or 2X Heroku dynos
- Older versions of Spree (prior to 2.2)
- Older versions of Ruby (prior to 2.1.x)
- Stores with moderately complex promotion rules
- Customers checking out with more than 15 items in their cart

We have found that the 1X and 2X dynos do not perform at a production-ready efficiency for a Spree store. Although some stores will work fine on the 2X dynos, if you're having speed problems we recommend running on the PX ("performance") dynos only.

Older versions of Spree have specific bloat and callback problems. Many of these were fixed in Spree 2.0, and even more were fixed in Spree 2.2. However, even on modern versions there are still areas of the app that can become bloated. Ruby version 2.0 is significantly faster than 1.9, and Ruby 2.1 is also marginally faster than 2.0. For this reason, we recommend using the latest version of Ruby when possible.

Promotion rules, especially ones written in a way that do not scale well, are the main source of bloat problems for Spree stores. Bloat associated with Promotions becomes exponentially more costly for a customer that has more than about 20 items in the cart at the time of checkout. Your mileage may vary, but we have seen customers hit timeouts when they cross the 20-25 items in their cart range.

### Background Jobs

Although not currently implemented, future plans for Spree include moving long running processes into background jobs. You can achieve much of this in your store by finding those long running operations and moving them into background jobs for your app. You will need to use the background worker of your choice (Resque, Delayed Job, Sidekiq )

### PostgreSQL Database Add-On

```shell
heroku addons:add heroku-postgresql
```

(If you want to use MySQL instead, you may want to look into the Amazon RDS service, which works will with Heroku dynos. Integration instructions can be found [here](https://devcenter.heroku.com/articles/amazon-rds))

### Specify Ruby version

You should specify the exact ruby version you want to run in your Gemfile:

```ruby
ruby '2.2.0'
```

Keep in mind that Spree 3.0.0 requires a version of Ruby greater than or equal to Ruby 2.1.0.
See [Heroku Ruby support page](https://devcenter.heroku.com/articles/ruby-support#build-behavior)
for details on build behaviour related to Ruby versions.

### Add Heroku 12 Factor Gem

Add the [Heroku 12 Factor gem](https://github.com/heroku/rails_12factor) to your Gemfile:

```ruby
gem 'rails_12factor', group: :production
```

This will enable your application to serve static assets and direct logging to stdout.

### Rails 4

For Spree 2.2 and earlier, be sure to add this to your application.rb file:
```
config.assets.precompile += %w(
      store/all.js
      store/all.css
      admin/all.js
   )
```

Spree versions up to 2.2 require a db connection on initialization. If you are setting up Spree 2.2 for the first time and you want to compile your assets on deploy, you may get stuck because a db connection is necessary to compile your assets.

A possible work around for this is first compile your assets locally (`rake assets:precompile RAILS_ENV=production`), commit the `public/assets/` directory, deploy it, then trash & remove the compiled assets, and re-deploy.

Also look into this [github thread](https://github.com/spree/spree/issues/3749#issuecomment-30987342)
and all related for further info on how you could accomplish a successful
Heroku deploy.

Fortunately a lot of work has been done so that Spree 2.3 doesn't touch db
on initialization. This issue about [preferences on initialization](https://github.com/spree/spree/issues/3833)
contains most of the context related.

### Asset Pipeline Rails 3

When deploying to Heroku by default Rails will attempt to initialize itself
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

To configure Spree to upload images to S3, please refer to the following [documentation](http://guides.spreecommerce.com/developer/s3_storage.html) or follow an [equivalent solution](https://devcenter.heroku.com/articles/paperclip-s3) from Heroku's website.

This strategy works reasonably well if you image is 3 MB or smaller. If your images are larger, you will need to implement the [Direct Upload Method](https://devcenter.heroku.com/articles/direct-to-s3-image-uploads-in-rails), which is significantly more complicated. 

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

You may then wish to set up an admin user as well which can be done if using
spree_auth_devise with a rake task:

```bash
$ heroku run rake spree_auth:admin:create
```

Enter an email & password, and then attempt to sign in to your application to
verify these credentials.

## SSL Support

For information about SSL support with Heroku, please read their [SSL Guide](https://devcenter.heroku.com/articles/ssl).
