---
title: "Deploying to Ninefold"
section: deployment
---

## Overview

This guide will walk you through deploying your Spree application with [Ninefold](http://ninefold.com).

This guide, like the others, assumes your app is in a 'ready-to-deploy' state and that your code is available in a hosted Git repository.  Ninefold requires access to this repository in order to deploy your application. 

***
Ninefold deployments require you to use Postgresql.  This means you need to have the pg gem specified in the production group in your gemfile. 

Alternatively, you can choose not to have Ninefold provision your database for you and you can setup a stand-alone server to host your MySQL or nosql database.  If you choose this option, Ninefold's database functionality (backups, replication, promotion, etc.) will not be available.
***

## Initial setup

### Create a Ninefold account

[Sign up](http://ninefold.com) with a username, your email address, and a password.

## Deployment

Once you've signed up, click the blue "Deploy now" button. This starts the deployment wizard which will step you through the process.

### Step 1. Deploy app

In this step, choose your hosted Git repository. Ninefold pulls your code in from [Github](http://github.com), [Bitbucket](http://bitbucket.com), or from your private Git URL. 

Sign in with your credentials for the repository and grant Ninefold permission to view your repository listings.

***
Git URL is an option if you want one specific repository to be visible to Ninefold. If it is a private repository, the SSH key will need to be added to your repository.

Skip down to step 3 if you've chosen the Git URL option.
*** 

### Step 2. Specify your repository

Choose the correct account, your Spree repository, and the branch you want to deploy from (this defaults to master).

Uncheck the box if you do not wish to have Ninefold automatically redeploy your app for every code revision.

Click Next.

### Step 3. Choose your architecture

Here, you will choose the correct architecture for your Spree application. Please consult the [Deployment options](http://guides.spreecommerce.com/developer/deployment_options.html) guide for RAM requirements. 

If you have set up your Spree application to use Redis for background work, our recommendation is to click "Create a dedicated worker server."

Click Next.

### Step 4. Configuration: Your app is now ready to be deployed

This step allows you to configure different settings for your Spree application.

Environment variables, such as S3 credentials, should be pasted into this section.

Add-ons such as Memcached, New Relic, and SendGrid can be chosen if you require them.

Click Next to begin the deploy process.

***
During the deployment process, Ninefold runs the following commands for you: `rake db:setup`, `rake db:migrate`, and `rake assets:precompile`.
***

### Code revisions

If you have automatic deployment turned on, every time you push new code to your Git repository, Ninefold will redeploy for you.

If this function has been turned off, log into Ninefold, click on your Spree app, and click Redeploy.

***
Alternatively, a redeploy can be done through the Ninefold CLI
***

## Ninefold CLI

Ninefold provides an easy to use command line interface to manage your Spree app.  To install the CLI, run this command in the root directory of your Spree application:

```bash
$ gem install ninefold
```

To log into your Ninefold account, type `ninefold signin`, and to view commands, type `ninefold help`.

The CLI is especially great for getting database backups, running console, checking logs, and running rake commands. More information about the CLI can be found here: [Ninefold CLI](https://github.com/ninefold/cli)

### Creating a Spree admin user

Type in Terminal:

```bash
$ ninefold console
```

Choose the Spree app, and Rails console will load up.  At the prompt, type:

```ruby
user = Spree::User.create!(:email => "your_email@example.com", :password => "yourpassword")
user.spree_roles.create!(:name => "admin")
```

Exit out of the console; your admin user should now be created.

## SSL Certificates

FOr information about SSL certificates on Ninefold, please check out the guide here: [SSL Certificates](https://help.ninefold.com/hc/en-us/articles/200847294-SSL-Certificates)