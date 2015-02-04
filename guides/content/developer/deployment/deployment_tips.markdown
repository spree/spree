---
title: "Deployment Tips"
section: deployment
---

## Overview

This guide is intended to provide some generally useful hints and tips\
for troubleshooting standard deployment issues, including:

* How static assets are served in production
* Enabling & Configuringn SSL use within Spree
* Email configuration
* and more ...

## Serving Static Assets

Rails applications (including Spree) use the convention of storing
public assets (images, JavaScripts, stylesheets, etc.) in a directory
named `public`. In development environments, Rails itself will
automatically handle requests for this static content by serving it from
the `public` directory. In production mode, however, Rails is not
configured to serve public assets unless specifically enabled. This
leaves you with two options.

### Configure Rails to Serve Public Assets

Rails has a `config.serve_static_files` setting that allows you to
override its default behavior in the production environment. If you want
Rails to serve you public assets you will need to change this setting in
`config/environments/production.rb` of your Rails app as follows:

```ruby
config.serve_static_files = true
```

***
There is a good reason why this is disabled by default in Rails
which is that Rails is not a general purpose web server. Servers such as
Apache and Nginx are optimized for rapidly serving up static content.
You should consider the advice of the Rails core team and let your
webserver do what it does best (as described in the next section.)
***

#### Configure the Web Server to Use the *public* Directory

The recommended approach for handling static assets is to allow your web
server to handle serving these files. If you want to follow this
approach just make sure that it's configured properly in the
`config/environments/production.rb` of your Rails app.

```ruby
config.serve_static_files = false
```
***
This is the default setting of Rails so it's also fine if this setting is missing or commented out.
***

The following is an example of how to configure Apache so that its document root is pointing to the `public` folder.

```bash
<VirtualHost *:80>
ServerName www.mystore.com
DocumentRoot /webapps/mystore/public
<Directory /webapps/mystore/public>
Allow from all
Options ~~MultiViews
</Directory>
</VirtualHost>
```

Each web server will have its own method for doing this so please consult the appropriate documentation for more details.

## Forcing SSL

To force SSL for all requests in your application, it is recommended you use the
[config.force_ssl](http://guides.rubyonrails.org/configuring.html) setting in the
`config/environments/production.rb` of your Rails app as follows:

```ruby
config.force_ssl = true
```

## Performance Tips

### Running in Production Mode

If you are noticing that Spree seems to be running slowly you should
make sure that you are running in "production mode." You can start your
server in production mode as follows:

```bash
$ bundle exec rails server -e production
```

Please consult your web server documentation for more details on
enabling production mode for your particular web server.

## Passenger Timeout

If you are running on [Passenger](http://www.modrails.com) then you may be noticing that the first request to your Spree application is very slow if the application has been idle for some time (or you have just restarted.) Consider changing the [PassengerPoolIdleTime](http://www.modrails.com/documentation/Users%20guide%20Apache.html#PassengerPoolIdleTime) as described in the Passenger documentation.

## Caching

Most stores spend a lot of time serving up the same pages over and over
again. In many cases, the content being served is exactly identical or
nearly identical for every user. In such cases, a caching solution may
be appropriate and can improve server performance by bypassing time
consuming operations such as database access. Rails provides several
excellent [caching
options](http://guides.rubyonrails.org/caching_with_rails.html) that you
should consider investigating.

A detailed description of Rails caching is beyond the scope of this
guide.

***
The Spree core team is actively considering some form of basic
caching support to make it easier to leverage the Rails caching options.
***
