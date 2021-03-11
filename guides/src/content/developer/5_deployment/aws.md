---
title: Amazon Web Services (AWS)
section: deployment
order: 0
---

Amazon Web Services offers reliable, scalable, and inexpensive cloud computing services. Free to join, pay only for what you use.

AWS is also one of the most popular choices for hosting a Spree application. There are several services you can use to host Spree on AWS, here we're briefly touch upon those options.

## AWS Elastic Beanstalk

The easiest way to run Spree or any other Ruby on Rails application on AWS is through AWS Elastic Beanstalk which is comparable to Heroku PaaS (Platform as a Service).

This is the recommended approach if you're just starting up. Please follow [Beanstalk Deployment guide](https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/ruby-rails-tutorial.html) for more details.

## AWS ECS

Another option is [Elastic Container Service](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/Welcome.html) to host and deploy your Docker containers. 

This is more advanced than Beanstalk and will require DevOps knowledge. For building Docker images we recommend you use [Spree Starter Dockerfile](https://github.com/spree/spree_starter/blob/main/Dockerfile.production).

## AWS EC2

[EC2](https://aws.amazon.com/ec2/) is the most basic offering, running a single or multiple instances of servers. This is the bare bones variant, you need to setup the deployment all by yourself using tools like [Capistrano](https://capistranorb.com/).

## Recommended AWS services

* [AWS S3](https://aws.amazon.com/s3/) - object storage service to store and read your uploaded files such as Product images etc. We **do not recommend** keeping your uploads on the same instance as the application.
* [AWS RDS](https://aws.amazon.com/rds/) - Amazon Relational Database Service (Amazon RDS) makes it easy to set up, operate, and scale a relational database in the cloud. Spree works great with multiple databases: [Amazon Aurora (both MySQL and PostgreSQL variants)](https://aws.amazon.com/rds/aurora/), [RDS PostgreSQL](https://aws.amazon.com/rds/postgresql/), [RDS MySQL](https://aws.amazon.com/rds/mysql/) and [RDS MariaDB](https://aws.amazon.com/rds/mariadb/)
* [AWS ElastiCache Redis](https://aws.amazon.com/elasticache/redis/?nc=sn&loc=2&dn=1) - we recommend setting up a Redis database for [Active Job background queue](https://guides.rubyonrails.org/active_job_basics.html), which we use for sending out transactional emails
* [AWS ElastiCache Memcached](https://aws.amazon.com/elasticache/memcached/?nc=sn&loc=2&dn=1) - we recommend using [Memcached as a cache storage](https://guides.rubyonrails.org/caching_with_rails.html) to increase performance and scalability of your Spree application
* [AWS CloudFront](https://aws.amazon.com/cloudfront/) - fast content delivery network (CDN) to speed up your asset (images/stylesheets/javascripts) delivery. This will greatly enhance your application responsiveness.
