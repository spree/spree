---
title: Navigating the Source
section: source-code
---

## Overview

This guide covers obtaining and running the source code. This is
primarily for developers who are interested in contributing code to the
Spree project or fixing the source code themselves. It is not necessary
to have a copy of the source code to run Spree. This guide covers the
following topics:

-   How Spree uses Git and GitHub to manage source code
-   The various gems that comprise the Spree source code
-   Building the gem from the source

## Git

The Spree source code is currently maintained in a
[Git](http://git-scm.com/) repository. Git is a distributed version
control system (DVCS)

The authoritative git repository is hosted by
[GitHub](https://github.com/) and is located in the
[spree](https://github.com/spree/spree/tree/master) repository. You can
clone the git repository using the following command:

```bash
$ git clone git://github.com/spree/spree.git
```

***
If you are planning on contributing to Spree you should create a
fork through GitHub and push fixes to clearly labeled branches (see the
[Contributors Guide](contributing) for details.)
***

### Browsing the Repository and/or Downloading the Source Code

You can easily browse the repository through GitHub's excellent [visual
interface](https://github.com/spree/spree/tree/master). GitHub also
contains a link to download a tarball copy of the latest source code as
well as links to [previous
versions](https://github.com/spree/spree/tags).

### Git for Windows

There are some well developed Git clients for Windows now. If you are on
a Windows box you might want to check out the
[Git for Windows](https://git-for-windows.github.io/) project.

### Monitoring Changes in the Source

If you would like to keep up to date on changes to the source you can
subscribe to the GitHub
[RSS feed](https://github.com/spree/spree/subscription) and you
will be notified of all the commits.

## Bundler

Spree uses the very excellent [bundler](http://gembundler.com/) gem to
manage its dependencies. We are assuming you have basic familiarity with
bundler. A detailed explanation of bundler can be found on [Bundler's
site](http://gembundler.com/).

You can install the gem dependencies for Spree after cloning the
repository using this Bundler-provided command:

```bash
$ bundle install
```

This allows you to quickly and painlessly have the exact gem depedencies
you need to work with Bundler.

## Layout and Structure

### Collection of Gems

The Spree gem itself is very minimal and consists mostly of a collection
of gems. These gems are maintained together in a single GitHub
repository and new versions of the gems are shipped with each new Spree
release. The official documentation (which you are reading now) covers
functionality provided by each of these gems.

Within the Spree source, each of the gems is organized into
subdirectories as follows:

| Gem            | Directory | Description               |
| :--------------| :---------| :-------------------------|
| spree_api      | api       | Provides REST API access  |
| spree_backend  | backend   | Backend functionality     |
| spree_cmd      | cmd       | Command line utility for installing Spree and creating extensions |
| spree_core     | core      | Core functionality - all other gems depend on this gem |
| spree_frontend | frontend  | Customer-facing functionality    |
| spree_sample   | sample    | Sample data and images    |

### Use of Rails Engines

Each of the gems in Spree makes use of Rails Engines. This functionality
was introduced in Rails 3.0 and allows Engines to behave in a manner
similar to fully-functional applications. Relying on this mechanism
provides several advantages:

#### An Intuitive Mechanism for Customization

Default Spree functionality is provided via the Rails engine gems.
Engines can provide several aspects traditionally associated with a
Rails application including (but not limited to):

-   Models, views and controllers
-   Routes
-   Helpers
-   Rake tasks
-   Generators
-   Locales

All of these elements can be overridden in the main Rails application.
Therefore, it is relatively simple to add Spree to your Rails
application and then customize it further by supplying your own elements
in that same application. A full discussion of Rails Engines is not
appropriate here. Please [consult the Rails Guides](http://edgeguides.rubyonrails.org/engines.html) for more information.

#### Simple Distribution and Installation as Gems

Using a Spree gem is as simple as adding it to your *Gemfile*:

```ruby
gem 'spree_core', '3.2.0'
```

Distribution of Spree (and its extensions) is also consistent with Rails
standards and modularity (see next.)

#### Consistency With a Rails Standard

Prior to version 0.30.0, Spree used a complex custom mechanism for
implementing "engine-like" functionality. While it was difficult to
strip this functionality out of Spree, the benefits are well worth it.
Spree now receives all of the massive testing and attention to detail
that comes for free when using the Rails core engine functionality,
rather than a custom solution.

#### Modularity

There are differing opinions on what belongs in the "core." People often express their opinion that Spree is either "getting too fat" or
"lacks basic features." By relying on these engines (and distributing
them as gems), developers are free to use only the parts of Spree that
they find useful. For instance, this would allow you to omit promotions
functionality or to replace the authentication mechanism.

For example, if you were to specify something like this in your
application's *Gemfile*:

```ruby
gem 'spree', '3.2.0'
```

It would require all the individual parts of Spree. However, if you only
wanted to require the "core" and "backend" parts of Spree, you would do
this:

```ruby
gem 'spree_core', '3.2.0'
gem 'spree_backend', '3.2.0'
```

## Building a Sandbox Application

When working with the Spree source you may find yourself wanting to see
how the code performs in the context of an actual application. This is
due to the fact that Spree is intended to be distributed as a gem and is
not designed to be run as a standalone application. Spree includes a
helpful Rake task for setting up such a test application.

To run this Rake task, go into the root of the Spree project and run
this command:

```bash
$ bundle exec rake sandbox
```

This will create a barebones rails application configured with the Spree
gem. It runs the migrations for you and sets up the sample data. The
resulting `sandbox` folder is already ignored by `.gitignore` and it is
deleted and rebuilt from scratch each time the Rake task runs.

## Building the Gem from the Source

The Spree gem can easily be built from the source. Run these two
commands in the root of the Spree project to do this:

```bash
$ bundle exec rake clean
$ bundle exec rake gem
```

Most likely you will want to build and install all of the related gems.
Fortunately, there is a simple Rake task for that.

```bash
$ bundle exec rake gem:install
```

You can also build just one specific gem.

```bash
$ cd core
$ bundle exec rake gem
```

## Tips for Working with the Source

### Using the "Edge" Code

If you are interested in simply using the latest edge code (as opposed
to contributing to it) then the simplest thing to do is add a *:github*
directive to your *Gemfile* and point it at the master branch.

```ruby
gem 'spree', github: 'spree/spree'
```

This will effectively use the latest code from the Git repository at the
time you run *bundle install*. This version of the code will be "frozen"
in your *Gemfile.lock* and will ensure that anyone else using your
project code is using the exact same version of the Spree code as you
are. You will need to update the bundle if you want to update to code
that is newer since the last time you updated.

```bash
$ bundle update
```

### Developing on the "Edge"

If you plan on using the edge code but also contributing back to Spree,
then you may be interested in the following approach. Create your Rails
app that will be using the Spree gem in a directory that has the same
parent as a locally cloned version of the Spree source. Then simply use
the following in your Gemfile.

```ruby
gem 'spree', path: '../spree'
```

***
See the excellent [Bundler documentation](http://gembundler.com) for more details.
***

### "-stable" branches

The Spree Git repository also contains stable branches for each minor Spree
version. For instance, there is a 3-2-stable branch which contains the latest
work for the 3.2.x branch of Spree. You may also decide to use this branch if you want the latest and greatest version of Spree:

```ruby
gem 'spree', github: 'spree/spree', branch: '3-2-stable'
```

Similarly, all main Spree extensions use this versioning scheme as well. For example, here's a line that would be used for `spree_auth_devise`:

```ruby
gem 'spree_auth_devise', github: 'spree/spree_auth_devise', branch: '3-1-stable'
```

!!!
While the best efforts of the Spree team are made to keep stable branches
stable, there has been situations in the past where changes required for a
net-positive result over the entire community have affected some applications
or extensions. If a change to a stable branch does break your application or
an extension, please report those breakages on the appropriate GitHub page.
!!!

### Creating Extensions

Spree provides a convenient generator for helping you to get started
with extensions.

```bash
$ spree extension foo
```

***
You need to have the Spree gem installed in order to use the `spree` command.
***

Please see the [Creating Extensions](extensions_tutorial) guide for more details.
