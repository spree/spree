require 'factory_girl'

FEATURES_PATH = File.expand_path('../..', __FILE__)

# load shared env with features
require File.expand_path('../../../../features/support/env', __FILE__)
Before do
  @configuration ||= AppConfiguration.find_or_create_by_name("Default configuration")
end
