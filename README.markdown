SUMMARY
=======

Spree is a complete open source commerce solution for Ruby on Rails.
It was developed by Sean Schofield under the original name of Rails
Cart before changing its name to Spree.

QUICK START (Running the Source)
================================

1. Clone the git repo

        git clone git://github.com/schof/spree.git spree
        
2. Install the gem dependencies

        rake gems:install
        
3. Bootstrap the database (run the migrations, create admin account, optionally load sample data.)

        rake db:bootstrap

4. Start the server

        script/server

QUICK START (Running the Gem)
=============================

1. Install spree Gem

        sudo gem install spree

    **NOTE:** This may take a while. The gem currently includes a frozen version of Rails 2.0.2

2. Create Spree Application

        spree <app_name>

3. Create your database and edit the _config/database.yml_ to taste.

        rake db:create

    You can skip this step if using sqlite3 as your database.

4. Bootstrap

        cd <app-name>
        rake db:bootstrap

5. Launch Application

        script/server

Browse Store
------------

http://localhost:xxxx/store

Browse Admin Interface
----------------------

http://localhost:xxxx/admin

i18n/l10n Support?
==================

**Basic** localization and internationalization **support** is now
added using the [Globalite Plugin][1] from Matt Aimonetti. 

Working features:

- Rails Localization
- UI Localization

In the near future:

- Content Localization

Please read [this][2], [this][3] and [this][4] to understand how the
plugin works.

Please, please, please ask Sean how you can help, lot of work is still
to be done.

[1]: http://www.railsontherun.com/globalite
[2]: http://code.google.com/p/globalite/wiki/RailsLocalization
[3]: http://code.google.com/p/globalite/wiki/UI_Localization
[4]: http://code.google.com/p/globalite/wiki/PluralizationSupport

**UPDATE:** Take a look at [i18n page on Spree wiki](http://support.spreehq.org/wiki/1/I18n)

Is Spree Ready for Production?
==============================

I have been asked by several people about the status of the Spree
project. I thought I would take a moment to address the current state
of the codebase and whether or not its “production ready.”

In my opinion, you can use Spree in a real world commerce application
right now. This is especially true if you are already committed to
using Ruby on Rails. What are the drawbacks to doing this? The major
drawback is that Spree is still “rough around the edges” so you will
be doing a lot of the polishing yourself. For instance, if you want to
have FedEx shipping calculations you will need to write/port your own.
On the other hand, the basic admin functionality is working and the
ActiveMerchant plugin support means you don’t have to worry about
credit cards. In fact, I have already built two production sites with
this software (under the old RailsCart name).

The only other Rails commerce application I am aware of is Substruct.
The last I looked at this project it was fairly basic as well. So if
you are going to start building your Rails project today, you have
three choices.

1. Write your own
2. Use Spree as your starting point and do lots of custom coding
3. Use Substruct as your starting point and do lots of custom coding

If you are uncomfortable with these three options then you should
consider another application framework.

The good news is that Spree is rapidly improving with each passing
day. The major effort right now is to rejigger the data model so that
it is rock solid. There is nothing “wrong” with the current data model
which is why it is ok to build a production Spree app with the
existing software. We’re just trying to make the data model as “future
proof” as possible. The more we improve the data model now, the less
disruptive it will be for users to upgrade to subsequent versions of
the software.

When will this refactoring be done? Our goal is to have our first beta
release in time for RailsConf (May 29). This means we will pushing
hard for another 6-8 weeks on all things data model. Once we go “beta”
we be on the next level of stability. There will be a lot less coding
needed to use Spree for your production site and we also hope to have
a standardized approach for the custom code you do need to write.