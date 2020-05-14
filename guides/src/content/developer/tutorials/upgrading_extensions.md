---
title: Updating Extensions to Rails 6 and Spree 4.1
section: advanced
---

### Zeitwerk compatibility

Zeitwerk is a new default code autoloader in Rails 6. See https://weblog.rubyonrails.org/2019/2/22/zeitwerk-integration-in-rails-6-beta-2/

This doesn't work well with the old approach to decorators (files that name ends with decorator.rb, eg. `app/models/spree/order_decorator.rb`) in Spree using `class_eval` (we should always use `Module.prepend`, [more on this](https://medium.com/@leo_hetsch/ruby-modules-include-vs-prepend-vs-extend-f09837a5b073)).

To fix this we need to convert all class_eval decorators to Module.prepend and name them properly according to Zeitwerk rules: https://github.com/fxn/zeitwerk#file-structure

Eg.

old decorator

`app/models/spree/order_decorator.rb`
```ruby
Spree::Order.class_eval do
  has_many :new_custom_model

  def some_method
     # ...
  end
end
```

new one:

`app/models/your_extension_name/order_decorator.rb`
```ruby
module YourExtensionName::OrderDecorator
  def self.prepended(base)
    base.has_many :new_custom_model
  end

  def some_method
    # ...
  end
end

::Spree::Order.prepend(YourExtensionName::OrderDecorator)
```

###  Travis CI configuration
You can always find up-to-date Travis CI config here: https://github.com/spree/spree/blob/master/cmd/lib/spree_cmd/templates/extension/travis.yml
For the rationale of the changes please look at the blame view: https://github.com/spree/spree/blame/master/cmd/lib/spree_cmd/templates/extension/travis.yml

### Appraisals config
You can always find up-to-date Appraisals config here: https://github.com/spree/spree/blob/master/cmd/lib/spree_cmd/templates/extension/Appraisals

For the rationale of the changes please look at the blame view: https://github.com/spree/spree/blame/master/cmd/lib/spree_cmd/templates/extension/Appraisals

After each change please remember to re-generate gemfiles by running:

```bash
bundle exec appraisal generate --travis
```

### Fixing Deface Overrides
Some Extensions still use Deface overrides to add some UI features, mainly in the admin panel. Deface isn't recommended. If you can use other methods.
Eg. If your extension adds a link to the Admin Panel menu you can do it this way https://guides.spreecommerce.org/developer/customization/view.html#adding-new-links-to-the-admin-panel-menu

If you're stuck on Deface please remember to prepare versioned overrides for both Spree 3.x and 4.x, eg.
https://github.com/spree-contrib/spree_static_content/commit/e4b9e4900024235158d0ec1a48a100b4732348ef

Spree 4 uses Bootstrap 4 and many partials and HTML structure changed compared to Spree 3.x.

Also - **remember to add deface gem to gemspec** as deface itself was removed as a dependency of Spree. eg. https://github.com/spree/spree_auth_devise/commit/d729689ca87d8586e541ffcc865ef1e0a5a79fe4

### Migrate to Spree Dev Tools
Replace all development dependencies with:

```ruby
s.add_development_dependency 'spree_dev_tools'
```

Replace `spec_helper.rb` contents with:

https://github.com/spree/spree/blob/777a284b4c70e69d32a05ffa61bbe3905d8f1297/cmd/lib/spree_cmd/templates/extension/spec/spec_helper.rb

Example migrations:

* https://github.com/spree/spree_gateway/pull/357
* https://github.com/spree-contrib/spree-product-assembly/pull/200
* https://github.com/spree/spree_auth_devise/pull/487

### Fixing deprecations
Please fix any Rails 6.1 deprecations eg.

```ruby
DEPRECATION WARNING: update_attributes! is deprecated and will be removed from Rails 6.1 (please, use update! instead)
```
