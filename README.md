### Switches out Spree’s entire frontend for a bootstrap 3 powered frontend.

This attempts to stay as closely to the original spree frontend markup as possible, only changing layout class names and adding a few DOM elements where required. Helper decorators have been kept to a bare minimum. It utilises the SCSS port of bootstrap 3 to keep inline with existing spree practices. It also includes support for `spree_auth_devise`.

**Ideally my goal is for this to be integrated, replacing spree’s increasingly tired current frontend.** Or at least becoming a viable drop-in alternative. It has several large advantages:

- Fully responsive - Mobile, tablet and desktop. With custom grids for each, collapsing elements, and full retina display support. Current spree only goes half way. 
- Just 39 lines of custom SCSS, replacing 1328 lines of undocumented spree CSS. Plus most of these lines only add some visual style to the header and footer and can be removed. 
- The entire frontend can be easily customized: colours, grid, spacing, etc, by just overriding [variables from bootstrap]() - giving a custom store design in minutes. 
- Bootstrap has some of the most [robust documentation](http://getbootstrap.com/css) of any framework, and a hugely active community. As this port uses only default bootstrap it means that entire spree frontend layout is documented by default. 
- Sites like [bootswatch](http://bootswatch.com) allow for one-file bootstrap drop-in spree themes.
- Lots of [spree community will for bootstrap](https://groups.google.com/forum/#!searchin/spree-user/bootstrap/spree-user/B17492QdnGA/AF9vEzRzf4cJ). 
- Though this uses ‘full bootstrap’ for simplicity, you can remove the unused SCSS components you don’t require for minimal file sizes. 

![spree_bootstrap_frontend preview](http://i.imgur.com/S50Gn7V.png)

Installation
-------

**WARNING: The master branch is currently built against spree edge!**

Add the following to your gemfile

```ruby
gem 'spree_bootstrap_frontend', github: '200creative/spree_bootstrap_frontend'
```

And run

```bash
bundle install
```

Done.

If you are running a stable branch of spree check if there is a compatible branch of spree_bootstrap_frontend and use that. For example:

```ruby
gem 'spree_bootstrap_frontend', github: '200creative/spree_bootstrap_frontend', branch: '2-2-stable'
```

Compatibility
-------

**WARNING: The master branch is currently built against spree edge!**

I’m targeting switching to a stable branch when `2-2-stable` is released, but as of now it's on `2.2.0.beta`. Stay tuned.

Customizing
-------

Copy the `spree_bootstrap_frontend.css.scss` file from `assets/stylesheets/store` into your application and edit as required.

To style your spree store just override the bootstrap 3 variables. The full list of bootstrap variables can be found [here](http://getbootstrap.com/customize/#less-variables). You can override these by simply redefining the variable before the `@import` directive.
For example:

```scss
$navbar-default-bg: #312312;
$light-orange: #ff8c00;
$navbar-default-color: $light-orange;

@import "bootstrap";
```

This uses the [bootstrap-sass](https://github.com/thomas-mcdonald/bootstrap-sass) gem. So check there for full cutomization instructions.

It’s quite powerful, here are some examples created in ~10 minutes with a few extra SCSS variables:

![spree_bootstrap_frontend theme](http://i.imgur.com/zh34YJ5.png)

Contributing
-------

Please fork and make a pull request.

**Tests, tests, tests.** Although care has been taken to try and keep HTML changes to a minimum, this plugin currently breaks tests.
To get it to a stage that it can be maintained moving forwards getting all tests passing is the highest priority.

**I’m looking for help maintaining this, so anyone who would like to become a core contributor please email me.** My email is in the gemspec.

Raise bugs in github’s [issues tracker](https://github.com/200Creative/spree_bootstrap_frontend/issues).

Further discussion can be had in the [spree google group](https://groups.google.com/forum/#!forum/spree-user).


Running tests
-------

Be sure to bundle your dependencies and then create a dummy test app for the specs to run against.

```bash
bundle
bundle exec rake test_app
bundle exec rspec spec
```

When testing your applications integration with this extension you may use it's factories.
Simply add this require statement to your spec_helper:

```ruby
require 'spree_bootstrap_frontend/factories'
```

Licence
-------

Copyright Alex James ([200creative.com](http://200creative.com)) and released under the BSD Licence.
