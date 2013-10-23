---
title: Heroku Endpoint Hosting
---

Once you have a tested, functioning endpoint, you need to get it hosted by a server on the web that the Hub can reach. [Heroku](https://www.heroku.com/) is a perfect option for hosting your endpoints, because you can do so for free, and because Heroku already has SSL (Secure Socket Layer) enabled through the shared herokuapp.com domain. Transmitting messages via SSL will ensure they are encrypted and not vulnerable to malicious sniffing attacks.

## Prerequisites

This tutorial assumes that you:

* have a functional endpoint you are ready to deploy,
* have a hosting account on Heroku,
* have installed the [Heroku Toolbelt](https://toolbelt.heroku.com/),
* are comfortable using the command line and git to interact with file systems, and
* have installed [bundler](http://bundler.io/)

## Steps

### Endpoint Setup

To start, you will need to add a Procfile to your endpoint's root directory to start a web dyno within your Heroku application.

---Procfile---
```ruby
web: bundle exec rackup config.ru -p $PORT```

***
Heroku [defines dynos](https://devcenter.heroku.com/articles/how-heroku-works#running-applications-on-dynos) as "isolated, virtualized Unix containers, that provide the environment required to run an application."
***

Make sure you declare the version of Ruby in your `Gemfile`:

```ruby
ruby "2.0.0"```

and run ```$ bundle install```. Next, you'll want to make sure you get your new endpoint stored in git:

```bash
$ git init
$ git add .
$ git commit -m "initial endpoint commit"```

!!!
Heroku will not successfully install the `endpoint_base` gem if you use the `git@github.com:spree/endpoint_base.git` path - it will give you a "Host key verification failed" error. Instead, change the `git` path to `https://github.com/spree/endpoint_base.git`.
!!!

Now that your endpoint has been prepared properly we can move on to heroku setup and deployment.

### Heroku Setup and Deployment

First we need to authenticate with Heroku. Do this by running the following command:

```bash
$ heroku login```

You will be prompted to enter your email address and password. If the system doesn't detect an SSH public key, it will ask if you want to create one. Answering `Y` (yes) generates and uploads the key to the server. This key is required to push your endpoint code to the server.

Next, create the application on your Heroku dyno and push your endpoint code to it by running the follwing two commands:

```bash
$ heroku create
$ git push heroku master```

!!!
Heroku requires the presence of a `Gemfile.lock` file. If you have this file listed in your endpoint's `.gitignore` file, you'll need to delete that line and commit the change (and the .lock file) before you push.
!!!

### Authentication With the Hub

The Hub uses a 32-character key to establish that incoming requests are legitimately coming from your endpoint. This key must be made entirely of numbers and lower-case letters. You set this key as an environment variable - `ENDPOINT_KEY` - on your Heroku server, then use the same key in the "Token" field when you register your endpoint with the Hub.

The [`endpoint_base`](https://github.com/spree/endpoint_base) gem (on which your endpoint should be based) will verify when a request is received that the two keys match. If they don't, a 401 (unauthorized) error is returned. This prevents spoofing requests that the Hub may receive from malicious sources.

With Heroku, you set environment variables using [config vars](https://devcenter.heroku.com/articles/config-vars).

```bash
$ heroku config:set ENDPOINT_KEY=12345abcde12345abcde12345abcde12```

You can verify that the `ENDPOINT_KEY` value was set correctly with the following command:

```bash
$ heroku config
ENDPOINT_KEY: 12345abcde12345abcde12345abcde12```

The previous command will list all of your environment variables and their values. Luckily, Heroku config vars are persistent across restarts and deploys, so you should not need to reset them once they are set.

### Renaming Your Application

The names that Heroku assigns by default to its deployed applications tend to be more poetic than you might prefer. If you are deploying a forked copy of the [Mandrill endpoint](https://github.com/spree/mandrill_endpoint), for example, you might prefer to have the application named "jane-doe-mandrill" rather than "bursting-sunset-3030".

To rename an application, you need only type the following command:

```bash
$ heroku apps:rename newname --app oldname```

If you have git remotes that point to your application, you'll need to update them as well.

```bash
$ git remote rm heroku
$ heroku git:remote -a newname```

The "newname" value in the last command above needs to match what you used in the `rename` command above. It must start with a letter and can only contain lowercase letters, numbers, and dashes.

### Testing

Now you can run a curl command against your deployed endpoint to verify that it is working correctly. For example, I deployed the [Zendesk endpoint](https://github.com/spree/zendesk_endpoint), which creates help desk tickets in your Zendesk account when it receives a `notification:error` or `notification:warning` message. I renamed my Heroku app to "zendesk-endpoint-copy".

Following is a sample JSON file you can save as `sample_error.json` to your home directory.

```json
{
  "message": "notification:error",
  "message_id": "518726r84910515003",
  "payload": {
    "subject": "The sky has fallen.",
    "description": "There was a sky, but now there is no sky.",
    "parameters": [
      {
        "name": "zendesk.url",
        "value": "https://myaccount.zendesk.com/api/v2/"
      },
      {
        "name": "zendesk.username",
        "value": "janedoe@example.com"
      },
      {
        "name": "zendesk.password",
        "value": "spree123"
      },
      {
        "name": "zendesk.requester_name",
        "value": "Chicken Little"
      },
      {
        "name": "zendesk.requester_email",
        "value": "chicken.little@example.com"
      },
      {
        "name": "zendesk.warning_priority",
        "value": "high"
      },
      {
        "name": "zendesk.error_priority",
        "value": "urgent"
      }
    ]
  }
}```

Next, run the following command from your home directory:

```bash
$ curl --data @./sample_error.json -i -X POST -H 'Content-Type:application/json' -H 'X_AUGURY_TOKEN:12345abcde12345abcde12345abcde12' https://zendesk-endpoint-copy.herokuapp.com/import```

It produces the following result:

```bash
HTTP/1.1 200 OK
Content-Type: application/json;charset=utf-8
Server: thin 1.5.1 codename Straight Razor
X-Content-Type-Options: nosniff
Content-Length: 174
Connection: keep-alive

{"message_id":"518726r84910515003","notifications":[{"level":"info","subject":"Help ticket created","description":"New Zendesk ticket number 62 created, priority: urgent."}]}```
