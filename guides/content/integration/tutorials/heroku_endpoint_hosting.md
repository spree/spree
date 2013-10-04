---
title: Hosting a Custom Endpoint on Heroku
---

Once you have a tested, functioning endpoint, you need to get it hosted to a server on the web that the Hub can reach. [Heroku](https://www.heroku.com/) is a perfect option for hosting your endpoints, because you can do so for free, and because Heroku already has SSL (Secure Socket Layer) enabled. Transmitting messages via SSL will ensure they are encrypted and not vulnerable to malicious sniffing attacks.

## Prerequisites

This tutorial assumes that you:

* have a functional tutorial you are ready to deploy, 
* have a hosting account on Heroku, 
* have installed the [Heroku Toolbelt](https://toolbelt.heroku.com/),
* are comfortable using the command line to interact with file systems, and
* have installed [bundler](http://bundler.io/)

## Endpoint Setup

You will need to add a Procfile to your application's root directory to start a web dyno within your Heroku application. 

---Procfile---
```ruby
web: bundle exec rackup config.ru -p $PORT
```

TODO: Investigate process type (web) above; see if it's what we really need here. Do we declare the port? If so, which one? Do we need the config.ru? We haven't in testing.

Now you'll want to make sure you get your new endpoint stored in git:

```bash
$ git init
$ git add .
$ git commit -m "initial endpoint commit"
```

## Heroku Setup


## Deployment

## Caveats

* Must (?) declare Ruby version.
* 