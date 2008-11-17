SUMMARY
=======

Spree is a complete open source commerce solution for Ruby on Rails.
It was developed by Sean Schofield under the original name of Rails
Cart before changing its name to Spree.

QUICK START
===========

Running from sources (latest and greatest features)
---------------------------------------------------

1. Clone the git repo

        git clone git://github.com/schof/spree.git spree

2. Create the necessary config/database.yml file
        
3. Install the gem dependencies

        rake gems:install
        
4. Bootstrap the database (run the migrations, create admin account, optionally load sample data.)

        rake db:bootstrap

5. Start the server

        script/server

Running the Gem
---------------

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

Deploying
=========

Deploy spree as a normal rails application. If you use apache+cgi/fastcgi take a look at the example .htaccess located in 

    public/.htaccess.example

i18n/l10n Support
=================

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