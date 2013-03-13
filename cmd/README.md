Spree Installer
===============

**Until the release of Spree 1.0 you must use the --edge option**

Command line utility to create new Spree store applications
and extensions

See the main spree project: https://github.com/spree/spree

Installation
------------

```ruby
gem install spree_cmd
```
This will make the command line utility 'spree' available.

You can add Spree to an existing rails application

```ruby
rails new my_app
spree install my_app
```

Extensions
----------

To build a new Spree Extension, you can run
```ruby
spree extension my_extension
```
Examples
--------

If you want to accept all the defaults pass --auto_accept

spree install my_store --edge --auto_accept

to use a local clone of Spree, pass the --path option

spree install my_store --path=../spree


Options
-------

* `--auto_accept` to answer yes to all questions
* `--edge` to use the edge version of Spree
* `--path=../spree` to use a local version of spree
* `--git=git@github.com:cmar/spree.git` to use git version of spree
  * `--branch=my_changes` to use git branch
  * `--ref=23423423423423` to use git reference
  * `--tag=my_tag` to use git tag

Older Versions of Spree
-----------------------

Versions of the Spree gem before 1.0 included a spree binary. If you
have one of these installed in your gemset, then you can alternatively
use the command line utility "spree_cmd". For example "spree_cmd install
my_app".



