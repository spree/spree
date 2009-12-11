More
====

*LESS on Rails.*

More is a plugin for Ruby on Rails applications. It automatically parses your applications `.less` files through LESS and outputs CSS files.

In details, More does the following:

* Recursively looks for LESS (`.less`) files in `app/stylesheets`
* Ignores partials (prefixed with underscore: `_partial.less`) - these can be included with `@import` in your LESS files
* Saves the resulting CSS files to `public/stylesheets` using the same directory structure as `app/stylesheets`

LESS
----

LESS extends CSS with: variables, mixins, operations and nested rules. For more information, see [http://lesscss.org](http://lesscss.org).

Upgrading from less-for-rails
=======================================

The old `less-for-rails` plugin looked for `.less` files in `public/stylesheets`. This plugin looks in `app/stylesheets`.

To migrate, you can either set `Less::More.source_path = Rails.root + "/public/stylesheets"`, or move your `.less` files to `app/stylesheets`.


Installation
============

More depends on the LESS gem. Please install LESS first:

	$ gem install less

Rails Plugin
------------

Use this to install as a plugin in a Ruby on Rails app:

	$ script/plugin install git://github.com/cloudhead/more.git

Rails Plugin (using git submodules)
-----------------------------------

Use this if you prefer to use git submodules for plugins:

	$ git submodule add git://github.com/cloudhead/more.git vendor/plugins/more
	$ script/runner vendor/plugins/more/install.rb


Usage
=====

Upon installation, a new directory will be created in `app/stylesheets`. Any LESS file placed in this directory, including subdirectories, will
automatically be parsed through LESS and saved as a corresponding CSS file in `public/stylesheets`. Example:

	app/stylesheets/clients/screen.less => public/stylesheets/clients/screen.css
	
If you prefix a file with an underscore, it is considered to be a partial, and will not be parsed unless included in another file. Example:

	<file: app/stylesheets/clients/partials/_form.less>
	@text_dark: #222;
	
	<file: app/stylesheets/clients/screen.less>
	@import "partials/_form";
	
	input { color: @text_dark; }

The example above will result in a single CSS file in `public/stylesheets/clients/screen.css`.

Any `.css` file placed in `app/stylesheets` will be copied into `public/stylesheets` without being parsed through LESS.


Configuration
=============

To set the source path (the location of your LESS files):

	Less::More.source_path = "/path/to/less/files"
	
You can also set the destination path. Be careful with the formatting here, since this is in fact a route, and not a regular path.

	Less::More.destination_path = "css"

More can compress your files by removing extra line breaks. This is enabled by default in the `production` environment. To change this setting, set:

	Less::More.compression = true

More inserts headers in the generated CSS files, letting people know that the file is in fact generated and shouldn't be edited directly. This is by default only enabled in development mode. You can disable this behavior if you want to.

	Less::More.header = false

To configure More for a specific environment, add configuration options into the environment file, such as `config/environments/development.rb`.

If you wish to apply the configuration to all environments, place them in `config/environment.rb`.

Heroku
======

The plugin works out-of-the-box on Heroku.

Heroku has a read-only file system, which means caching the generated CSS with page caching is not an option. Heroku supports caching with Varnish, though, which the plugin will leverage by setting Cache-Control headers so that generated CSS is cached for one month.

Tasks
=====

More provides a set of Rake tasks to help manage your CSS files.

To parse all LESS files and save the resulting CSS files to the destination path, run:

	$ rake more:parse

To delete all generated CSS files, run:

	$ rake more:clean

This task will not delete any CSS files from the destination path, that does not have a corresponding LESS file in the source path.


Git
===

If you are using git to version control your code and LESS for all your stylesheets, you can add this entry to your `.gitignore` file:

	public/stylesheets


Documentation
=============

To view the full RDoc documentation, go to [http://rdoc.info/projects/cloudhead/more](http://rdoc.info/projects/cloudhead/more)


Contributors
============
* August Lilleaas ([http://github.com/augustl](http://github.com/augustl))
* Logan Raarup ([http://github.com/logandk](http://github.com/logandk))

LESS is maintained by Alexis Sellier [http://github.com/cloudhead](http://github.com/cloudhead)
