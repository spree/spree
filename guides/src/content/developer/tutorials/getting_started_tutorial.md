---
title: Getting Started
section: tutorial
order: 0
---

## Prerequisites

Before starting this tutorial, make sure you have [Docker](https://docs.docker.com/get-docker/) installed on your system. This is fairly straightforward, but differs depending on which operating system you use.

If you would like to add Spree to your existing Ruby on Rails application, please [follow this guide instead](/developer/tutorials/existing_app_tutorial.html).

## Installation

1. Download [Spree Starter](https://github.com/spree/spree_starter/archive/main.zip)
2. Unzip it
3. Rename `spree_starter-main` directory as you please
4. Run `bin/setup` in said directory

## Hello, Spree Commerce

You now have a functional Spree application after running only a few commands!

To see your application in action, open a browser window and navigate to [http://localhost:3000](http://localhost:3000). You should see the Spree default home page:

![Spree Application Home Page](../../../images/developer/storefront/1.png)

To stop the web server, hit Ctrl-C in the terminal window where it's running. In development mode, Spree does not generally require you to stop the server; changes you make in files will be automatically picked up by the server.

### Logging Into the Admin Panel

The next thing you'll probably want to do is to log into the admin interface.
Use your browser window to navigate to
[http://localhost:3000/admin](http://localhost:3000/admin). You can login with
the username `spree@example.com` and password `spree123`.

Upon successful authentication, you should see the admin screen:

![Admin Screen](../../../images/developer/overview.png)

Feel free to explore some of the Admin Panel features that Spree has to offer and to verify that your installation is working properly.

## Next steps

If you've followed the steps described in this tutorial, you should now have a fully functional Spree application up and running.

For starting/stopping/restarting application please refer to [Spree Starter README](https://github.com/spree/spree_starter#running-the-project).

We recommend you should also continue to [Customization section](/developer/customization/storefront.html) to learn how to modify and extend your Spree application.

To learn more about Spree internals please refer [Core section](/developer/core/orders.html).
