Overview
--------

This gem provides the so-called "core" functionality of Spree and is a requirement for any Spree application or
store.  The basic data models as well as product catalog and admin functionality are all provided by this gem.


Security Warning
----------------

*This gem provides absolutely no authentication and authorization.  You are strongly encouraged to install
and use the spree-auth gem in addition to spree-core in order to restrict access to orders and other admin
functionality.*


Running Tests
-------------

You need to do a quick one-time creation of a test application and then you can use it to run the tests.

    rake test_app

Then run the tests

    rake spec

Misc
----

authentication by token example

    http://localhost:3000/?auth_token=oWBSN16k6dWx46TtSGcp