---
title: Contributing to Spree
section: source-code
---

## Overview

Spree is an open source project. Anyone can use the code, but more importantly, anyone can contribute. This is a group effort and we value your input. Please consider making a contribution to help improve the Spree project. This guide covers:

* How to file a ticket when you discover a bug
* How to contribute fixes and improvements to the core
* Information on how to improve the documentation

## Who can contribute?

Spree is an open source project and as such contributions are always welcome. Our community is one which encourages involvement from all developers regardless of their ability level. We ask that you be patient with the other members of the community and maintain a respectful attitude towards other people's work. Open source is a great way to learn a new technology so don't be afraid to jump right in, even if you are new to Ruby/Rails.

## Before you contribute

Open source projects tend to be a collaborative effort. Since many people are relying upon Spree for their real world applications, changes to the code can have major implications. Before you write a bug fix or code a new feature, you should find out if anybody is interested in your proposed change. You may find that the thing you're trying to "fix" is actually desired behavior. You might also discover that someone else is working on it. Either way you can save yourself valuable time by announcing your intentions before starting work.

### Mailing List

One of the best places for communication is the [spree-user mailing list](http://groups.google.com/group/spree-user). You can search this list of previous discussions and get a sense for whether you're trying to address something new.

### IRC

There is a #spree chat room on the irc.freenode.net network. Sometimes the core contributors hang out there and you can get some feedback on your idea. More information on how to connect is on our [blog](http://spreecommerce.com/blog/irc-101).

!!!
The #spree chat room is not monitored as carefully as the mailing list. Sometimes you'll get lucky and someone will answer your question but we can't provide real time responses to everyone with a question/problem/idea. The mailing list is a much better way to communicate, and it gives everyone the chance to provide a thoughtful response. It's also more permanent than anything discussed on IRC.
!!!

### Notification via GitHub Issues

You can also search existing bug reports/issues and file a new one if you do not find an issue relevant to your proposed change. See [Filing an Issue](#filing-an-issue) for more details.

***
The important thing is that you communicate your intention in advance of doing a lot of work. Simple bug fixes and non-controversial changes do not require this approach but you can save some time by suggesting an improvement and having it rejected before you write a bunch of the code.
***

## Spree's Release Policy

* Deprecation warnings are to be added in patch releases (i.e. 2.2.1) and the code being deprecated will only be removed in minor versions. For example, if a deprecation warning is added in 2.2.1, 2.2.2 will still contain the same deprecation warning but in 2.3.0 the deprecation warning and the code will be gone.

* Master branch receives *all* patches, including new features and breaking API changes (with deprecation warnings, if necessary).

* One branch "back" from master (currently 3-0-stable) receives patches that fix all bugs, and security issues, and modifications for recently added features (for example, split shipments). Breaking API changes should be avoided, but if unavoidable then a deprecation warning MUST be provided before that change takes place.

* Two branches "back" from master (currently 2-4-stable) receives patches for major and minor issues, and security problems. Absolutely no new features, tweaking or API changes.

* Three branches back from master (currently 2-3-stable) receives patches for major issues and security problems. The severity of an issue will be determined by the person investigating the issue. Absolutely no features, tweaking or API changes.

* Four branches and more "back" from master (currently 2-2-stable and lesser) receive patches only for security issues, as people are still using these branches and may not be able to or wish to upgrade to the latest version of Spree.

To determine how often minor branches of Spree are released, please check the [RubyGems version page for Spree](http://rubygems.org/gems/spree/versions).

We strongly encourage people to upgrade to using the latest Spree releases to avoid being stuck on a release that is no longer maintained.

## Filing an Issue

If you would like to file a bug report, please create an issue in our [GitHub Issues Tracker](https://github.com/spree/spree/issues). You should do a basic search of the issues database before creating a new issue to ensure that you are not creating a duplicate issue.

When filing an issue on the Spree project, please provide these details:

* A comprehensive list of steps to reproduce the issue.
* What you're *expecting* to happen compared with what's *actually* happening.
* The version of Spree *and* the version of Rails.
* Your application's complete Gemfile, as text (*not as an image*)
* Any relevant stack traces ("Full trace" preferred)

Without this information, we may be unable to debug your issue promptly. This information is typically all that is required in order to be able to solve a problem quickly and efficiently.

***
Please do not assign labels or create new labels to your issue. We will assign the appropriate labels to ensure your ticket is handled in the appropriate manner.
***

### When to File an Issue

You should file an issue if you have found (or suspect) a bug in the "core" functionality of Spree. If you have found a bug in one of the extensions, please file an issue with the appropriate extension project in GitHub. If you're not sure if the behavior you're experiencing is intentional just ask on the mailing list and someone will encourage you to file a ticket if your issue sounds like a bug (as opposed to a feature.)

### How We Prioritize Issues

Spree is a very large project with lots of activity. We try our best to respond to all of the questions and issues our users have.  We use the following criteria to prioritize issues:

* Does this bug effect the latest stable release?
* Are there details on how to reproduce the problem?
* Is there a patch associated with the issue?
* Is there a test included in the patch?
* Has someone else verified the bug?

We give highest priority to issues where the answer is "yes" to all of these questions. Next highest priority is for issues that answer "yes" to most of these questions, particularly the first few criteria.

***
You need to include a brief description of the problem and simple steps needed to reproduce it. If you fail to supply this minimum level of information your issue will likely be ignored.
***

### Providing a Patch

If you are filing an issue and supplying a patch at the same time, please file a ["Pull Request"](#creating-a-pull-request) instead. The pull request will also create an issue at the same time but it's superior to just creating an issue because the code and issue can be linked.

If the ticket already exists, however, and you want to supply a patch after the fact, you can simply reference the issue number in your commit message. For example, if your commit fixed issue #123 you could use the following commit message:

  Fixed a problem with Facebook authentication.

  [Fixes #123]

GitHub will automatically detect this commit message when you push it and link the issue. Please see the detailed [GitHub Issues](https://github.com/blog/831-issues-2-0-the-next-generation) blog post for more details.

We add code from Pull Requests to spree using the [hub gem](https://github.com/defunkt/hub), in particular the `hub am` command, which is used like this:

```bash
$ hub am -3 https://github.com/spree/spree/pull/<number>
```

This command will apply the commits from the pull request to the current branch, using a 3-way merge as a fallback. This means that we can run this command in order to apply the patch to different branches. A pull request applied in this way leads to tidier commit history, with no merge commits visible.

***
For this reason, there is no need to create multiple pull requests for Spree's different branches. Please only create one pull request per change and simply mention inside the pull request that it can apply to multiple branches. If a patch does not apply cleanly to a branch, the Spree team may ask you for another one which applies to the other branch.
***

## Feature Requests

We're interested in hearing your ideas for new features but creating feature requests in the Issue Tracker is not the proper way to ask for a feature. A feature request is any idea you have to improve the software experience that is not strictly related to a bug or error of omission.

***
Feature requests that are accompanied by source code are always welcome. In this case you should read the next section on [creating a pull request](#creating-a-pull-request).
***

!!!
Feature requests without accompanying code will be closed immediately. We simply cannot respond efficiently to feature requests through our Issue Tracker. If you want to suggest a feature, please use the [mailing list](http://groups.google.com/group/spree-user).
!!!

## Creating a Pull Request

If you are going to contribute code to the Spree project, the best mechanism for doing this is to create a pull request in GitHub. If you're unfamiliar with the general concept of pull requests you may want to read more on [pull requests in GitHub](https://help.github.com/articles/using-pull-requests).

***
If your code is associated with an existing issue then you can [provide a patch](#providing-a-patch) instead of creating a pull request.
***

### Creating a Fork

The official Spree source code is maintained in GitHub under the [spree/spree](https://github.com/spree/spree) project. There is a [core team](http://spreecommerce.com/core_team) of developers who are responsible for maintaining the quality of the source code. Your changes will ultimately need to be merged into the official project by a core member.

Thanks to [GitHub](https://github.com/), however, you do not have to wait for a core member to get started with your fix. You simply need to "fork" the project and then start hacking.

***
See the GitHub guide on [creating forks](https://help.github.com/articles/fork-a-repo) for more details.
***

### Topic Branches

Git branches are "cheap." Creating branches in Git is incredibly easy and it's an ideal way to isolate a specific set of changes. By keeping a specific set of changes isolated, it will help us to navigate your fork and apply only the changes we're interested in. You should create a clean branch based on the latest spree/master when doing this. It is important you follow these steps exactly, it will prevent you from accidentally including unrelated changes from your local repository into the branch.

For example, if we were submitting a patch to fix an issue with the CSS in the flash error message you could create a branch as follows:

```bash
$ git remote add upstream git://github.com/spree/spree.git
$ git fetch upstream
$ git checkout -b fix-css-for-error-flash --track upstream/master
```

The fetch command will grab all of the latest commits from the Spree master branch. Don't worry, it doesn't permanently alter your working repository and you can return to your master branch later. The track part of the command will tell git that this branch should track with the remote version of the upstream master.  This is another way of saying that the branch should be based on a clean copy of the latest official source code (without any of your unrelated local changes.)

You can then do work locally on this topic branch and push it up to your GitHub fork when you are done. So in our previous example we do something like:

```bash
$ git push origin fix-css-for-error-flash
```

Of course if you want the fix for yourself to use in your own local code you should probably merge it down to your own personal master branch that you're using for development

```bash
$ git checkout master
$ git merge fix-css-for-error-flash
```

You should probably also clean up after yourself a little. The branch has been pushed to GitHub and you've merged it locally so you don't really need a local copy of the branch laying around.

```bash
$ git branch -D fix-css-for-error-flash
```

### Follow the Coding Conventions

Spree follows a simple set of coding style conventions.

* Two spaces, no tabs.
* No trailing whitespace. Blank lines should not have any space.
* Indent after private/protected.
* Prefer `&&`/`||` over `and`/`or`.
* Prefer class << self block over self.method for class methods.
* `my_method(my_arg)` not `my_method( my_arg )` or `my_method my_arg`.
* `a = b` and not `a=b`.
* `{ a + b }` and not `{a + b}`
* -> symbol over lambda
* Ruby 1.9 hash syntax { key: :value } over Ruby 1.8 hash syntax { :key => :value }
* Alphabetize the class methods to keep them organized.
* Follow the conventions you see used in the source already.

These are some guidelines and please use your best judgment in using them.

### Including a Test

Ideally your pull request will also include a test that verifies a bug (or the absence of the new feature) before your fix and also verifies proper functionality when you are finished. Please read the [Testing Guide](testing) for more information on writing and running your tests.

***
Pull requests with tests are given top priority. Failure to include a test will likely delay acceptance of your patch.
***

### Creating the Pull Request

Once your code is ready to go and you have pushed your [topic branch](#topic-branches) to GitHub then you are ready to create the pull request and notify the Spree team that your contribution is ready. You do this by browsing your project in GitHub and changing to the topic branch you just pushed. Once you are on the topic branch simply create a pull request by pressing the "Pull Request" button.

***
The GitHub guide on [pull requests](https://help.github.com/articles/using-pull-requests) describes this in more detail with screenshots if you're still confused on this part.
***

## Contributing to the Documentation

Improvements to the documentation are encouraged. The primary source of documentation are the guides (_HINT: You are reading one now._). You may make edits to the guide in your fork and then pull request for them to be updated to this site.

To build the documentation normally simply clone and install.

```bash
$ git clone git://github.com/spree/spree.git
$ cd spree/guides
$ bundle install
$ bundle exec guides build
```

Then simply use the nanoc command to compile and preview the guides in your browser at http://localhost:3000

```bash
$ nanoc compile
$ nanoc view
```

## Markdown Conventions

It is helpful to standardize some markdown conventions so readers learn to recognize visual cues as they work their way through the documentation and tutorials. Following are the conventions used for the Spree documentation:

####Class Names####

When referencing the name of a class, it should be capitalized. If you are writing explanatory prose and not a section of code, the class name should be blocked out with tick (`) marks. For example:

    To begin using your custom `User` class, you must first...

Having the namespace for the class is optional, but should be included when omitting it could cause confusion.

An instance of a class should be lowercase, normal font:

    You can view all of the orders for a particular user.

####Buttons, Links, Section Names, Form Elements####

These should always reference the correct label and can have their names quoted. Examples:

* Click the "Filter Results" button to update the results.
* Follow the "Stock Transfers" link.
* Information displayed in the "Purchase Funnel" section gives you information...
* If you check "Receive Stock" while creating a new transfer...

####States, Attributes, Methods, Events, and Parameters####
When referring to the state of an object - an order, for example - the state name should be lowercase and set off with tick (`) marks. For example:

    Orders that are in the `address` state do not have valid shipping and billing addresses assigned to them yet.

This same style is used for attribute names and their settings, method names, event names, parameter names, parameter settings, and data types.

####Path Names####
Path names should be set off with tick (`) marks, and should include enough of the directory structure to make it clear which file is being referenced. For example:

    They are defined in `core/app/models/spree/app_configuration.rb`...

####Adding Emphasis####
Any text that needs to be emphasized should be in _italics_.

    Only the shipping options in the _shipping_ address are presented.

####Terminal Blocks####
You can specify terminal blocks by setting it off with <code>```bash</code>. In addition, you can differentiate commands you are using from output returned by using the `$` precursor for input and `=>` precursor for output.

```bash
$ irb
$ c = "Hello world"
$ c
=> "Hello world"
```

####Special Blocks####

Certain blocks of text can be wrapped in sets of three characters, which will place them in divs with appropriate CSS classes. They are:

| *** | Notes. |
| !!! | Warnings. |
| $$$ | TODO's |
| --- | A title bar; especially useful for headings for code samples. |
