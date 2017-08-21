---
title: "Deploying to Heroku"
section: deployment
---

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
- Stores with moderately complex promotion rules
- Customers checking out with more than 15 items in their cart

We have found that the 1X and 2X dynos do not perform at a production-ready efficiency for a Spree store. Although some stores will work fine on the 2X dynos, if you're having speed problems we recommend running on the PM ("performance") dynos only.

### Background Jobs

Although not currently implemented, future plans for Spree include moving long running processes into background jobs. You can achieve much of this in your store by finding those long running operations and moving them into background jobs for your app. You will need to use the background worker of your choice (Resque, Delayed Job, Sidekiq )

### PostgreSQL Database Add-On

```shell
heroku addons:add heroku-postgresql
```

(If you want to use MySQL instead, you may want to look into the Amazon RDS service, which works well with Heroku dynos. Integration instructions can be found [here](https://devcenter.heroku.com/articles/amazon-rds))

### Paperclip image quality issues
Heroku currently defaults to a surprisingly old version of ImageMagick (6.5 as of March 2014) which can cause problems.  Aside from the fact that 6.5 is missing some of the newer command line arguments that Paperclip can invoke, its [image conversion quality is noticeably inferior](http://i.imgur.com/dqeNdlW.png) to that of the current release.  You can easily work around this by [using a Heroku buildpack to provide the latest ImageMagick release](https://github.com/spree/spree/pull/3104#issuecomment-36977413).  You may have to `:reprocess!` your images after upgrading ImageMagick.

### S3 Support

Because Heroku's filesystem is readonly, you will need to configure Spree to
upload the assets to an off-site server, such as S3. If you don't have an S3
account already, you can [set one up here](http://aws.amazon.com/s3/)

This guide will assume that you have an S3 account already, along with a bucket
under that account for your files to go into, and that you have generated the
access key and secret for your S3 account.

To configure Spree to upload images to S3, please refer to the following [documentation](/developer/s3_storage.html) or follow an [equivalent solution](https://devcenter.heroku.com/articles/paperclip-s3) from Heroku's website.

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
