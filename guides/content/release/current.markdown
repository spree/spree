Spree X.Y.Z Release Notes
-------------------------

This document summarises the main changes in release X.Y.Z

Also check Spree’s *CHANGELOG* file and the ticket system for detailed
information of changes.

endprologue.

### Upgrade procedure

TODO

### I18n Changes

Spree now stores all of the translation information in a separate Github
project known as [spree\_i18n](http://github.com/spree/spree_i18n). This
is a stand alone project with a large number of volunteer committers who
maintain the locale files. This is basically the same approach\
followed by the Rails project which keeps their localizations in
[rails-i18n](http://github.com/svenfuchs/i18n).

The project is actually a Spree extension. This extension contains
translations only. The rest of code needed to support the i18n features
is part of the Spree core.

WARNING: You will need to install the
[spree\_i18n](http://github.com/spree/spree_i18n) extension if you want
to use any of the community supplied translations of Spree.

See the [i18n](i18n.html) guide for further details.
