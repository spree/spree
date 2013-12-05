**Switches out Spree’s entire frontend for a bootstrap 3 powered frontend.**

This attempts to stay as closely to the original markup as possible, only changing layout class names and adding a few DOM elements where required. Helper decorator changes have been kept to a bare minimum. It utalises the SCSS port of bootstrap to keep inline with existing spree practices. It also includes support for spree_auth_devise.

**Ideally my goal is to for this to be integrated, replacing spree’s increasingly tired current frontend.** Or at least becoming a viable supported alternative. It has several large advantages:

- Fully responsive - Mobile, tablet and desktop. With custom grids for each, collapsing elements, and full retina display support. Current spree only goes half way. 
- Just 40 lines of custom LESS, replacing 1328 lines of undocumented CSS. Plus most of these lines only add some visual style to the header and footer and can be removed. 
- As it’s SCSS powered the entire frontend can be easily customized: colours, grid, spacing, etc, by just overriding [variables from bootstrap]() - giving a custom store design in minutes. 
- Bootstrap has some of the most [robust documentation](http://getbootstrap.com/css) of any framework, and a hugely active community. As this port uses only default bootstrap it means that entire spree frontend layout is documented by default. 
- Sites like [bootswatch](http://bootswatch.com) allow for one-file bootstrap drop-in spree themes, which is currently totally impractical. 
- Lots of [spree community will for bootstrap](https://groups.google.com/forum/#!searchin/spree-user/bootstrap/spree-user/B17492QdnGA/AF9vEzRzf4cJ). 
- Though this uses ‘full bootstrap’ for simplicity, you can remove the unused LESS components you don’t require for minimal file sizes. 

[images]

### Installation

Add the following to your gemfile

     gem 'spree_bootstrap_frontend', github: '200creative/spree_bootstrap_frontend'

And run

    bundle install

Done.

If you are running a different branch of spree check if there is a compatible branch of spree_bootstrap_frontend.

### Compatibility

This is currently built against edge! I’m targeting switching to a stable branch when 2-2-stable is release, but as of now it's on 2.2.0.beta. Stay tuned.

### Contributing

Please fork and make a pull request.

**Tests, tests, tests.** Although I’ve taken care to try and keep html changes to a minimum, this plugin currently breaks tests.
To get it to a stage that it can be maintained moving forwards getting all tests passing is the highest priority.

**I’m looking for help maintaining this, so anyone who would like to become a core contributor please email me.**

Raise bugs in github’s [issues tracker](https://github.com/200Creative/spree_bootstrap_frontend/issues).

Further discussion can be had in the [spree google group](https://groups.google.com/forum/#!forum/spree-user).


### Running tests

Be sure to bundle your dependencies and then create a dummy test app for the specs to run against.

```shell
bundle
bundle exec rake test_app
bundle exec rspec spec
```

When testing your applications integration with this extension you may use it's factories.
Simply add this require statement to your spec_helper:

```ruby
require 'spree_bootstrap_frontend/factories'
```

### Licence

Copyright Alex James ([200creative.com](http://200creative.com)) and released under the BSD Licence.