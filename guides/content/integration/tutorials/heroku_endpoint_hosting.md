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

$$$
Investigate process type (web) above; see if it's what we really need here. Do we declare the port? If so, which one? Do we need the `config.ru` part of the previous command? We haven't in testing. Do we need to declare the ruby version?
$$$

Now you'll want to make sure you get your new endpoint stored in git:

```bash
$ git init
$ git add .
$ git commit -m "initial endpoint commit"
```

## Heroku Setup

Log into your Heroku account:

```bash
$ heroku login
```

You will be prompted to enter your email address and password. If the system doesn't detect an SSH public key, it will ask if you want to create one. Answering `Y` (yes) generates and uploads the key to the server. This key is required to push your endpoint code to the server.

### Authentication

The Hub uses a 32-character key to establish that incoming requests are legitimately coming from your endpoint. This key must be made entirely of numbers and lower-case letters. You set this key as an environment variable - `ENDPOINT_KEY` - on your Heroku server, then use the same key in the "Token" field when you register your endpoint with the Hub.

The [`endpoint_base`](https://github.com/spree/endpoint_base) gem (on which your endpoint should be based) will verify when a request is received that the two keys match. If they don't, a 401 (unauthorized) error is returned. This prevents spoofing requests that the Hub may receive from malicious sources.

With Heroku, you set environment variables using [config vars](https://devcenter.heroku.com/articles/config-vars). 

```bash
$ heroku config:set ENDPOINT_KEY=12345abcde12345abcde12345abcde12
```

You can verify that the `ENDPOINT_KEY` value was set correctly with the following command:

```bash
$ heroku config:get ENDPOINT_KEY
12345abcde12345abcde12345abcde12
```

or even:

```bash
$ heroku config
ENDPOINT_KEY: 12345abcde12345abcde12345abcde12
```

The previous command will list all of your environment variables and their values. Luckily, Heroku config vars are persistent across restarts and deploys, so you should not need to reset them once they are set.

## Deployment

## Caveats

* Must (?) declare Ruby version.
* 