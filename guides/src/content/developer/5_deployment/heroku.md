---
title: Heroku
section: deployment
order: 1
---

## Overview

Heroku is a Platform as a Service that makes deploying and hosting Spree applications super easy.

You should just follow [Heroku Rails 6 guide](https://devcenter.heroku.com/articles/getting-started-with-rails6). 

We recommend you start and stick to Heroku if you do not have DevOps-skilled team members. [Spree Starter](https://github.com/spree/spree_starter) is pre-configured to work with Heroku out of the box.

## Dynos

[Heroku Dynos](https://www.heroku.com/dynos) are lightweight, isolated environments that provide compute and run yuor application.

There's 2 type of dynos:

* Web - for running the web interface of yuour Store (Storefront, API, Admin Panel)
* Worker - for running background jobs via [Active Job](https://guides.rubyonrails.org/active_job_basics.html) such as email send out, report generation, etc

### Recommended sizing

Dynos | Staging environment | Production environment
--- | --- | ---
**web** | 1 x Standard-2x | 1 x Standard-2x (small traffic) or 1 x Performance-M (medium traffic)
**worker** | 1 x Standard-1x | 1 x Standard-1x

## Add-Ons

[Heroku Add-Ons](https://elements.heroku.com/addons) are tools and services for developing, extending, and operating your app.

### Recommended Add-Ons and plans

Plan | Staging environment | Production environment
--- | --- | ---
Bucketeer | Hobbyist |Micro
Edge | Hobby | Micro
Heroku Postgres | Hobby Basic | Standard-0
Heroku Scheduler | N/A | N/A |
Memcached Cloud | Free | 100 MB
Papertrail | Choklad | Fixa
Redis Cloud | Free | 100 MB
Scout APM | Free | Free (small traffic) or Eldora (medium traffic)
Sendgrid | Free | Bronze
Sentry | Free | Small

## Other resources

* https://devcenter.heroku.com/categories/reference

* https://devcenter.heroku.com/articles/getting-started-with-rails6

* https://devcenter.heroku.com/categories/monitoring-metrics

* https://devcenter.heroku.com/articles/deploying-rails-applications-with-the-puma-web-server
