require File.expand_path("../../../spec/support/blueprints", __FILE__)

Before { Machinist.reset_before_test }

Machinist.configure do |config|
  config.cache_objects = false
end