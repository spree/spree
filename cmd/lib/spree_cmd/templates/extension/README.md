<%= class_name %>
<%= "=" * class_name.size %>

Introduction goes here.

Installation
------------

Add <%= file_name %> to your Gemfile:

```ruby
gem '<%= file_name %>'
```

Bundle your dependencies and run the installation generator:

```shell
bundle
bundle exec rails g <%= file_name %>:install
```

Testing
-------

Be sure to bundle your dependencies and then create a dummy test app for the specs to run against.

```shell
bundle
bundle exec rake test_app
bundle exec rspec spec
```

When testing your applications integration with this extension you may use it's factories.
Simply add this require statement to your spec_helper:

```ruby
require '<%= file_name %>/factories'
```

Copyright (c) <%= Time.now.year %> [name of extension creator], released under the New BSD License
