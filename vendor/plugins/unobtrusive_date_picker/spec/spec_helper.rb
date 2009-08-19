ENV["RAILS_ENV"] = "test"
PLUGIN_ROOT = File.expand_path(File.join(File.dirname(__FILE__), '..'))

require 'rubygems'
require 'spec'
require 'active_support'
require 'action_view'
require 'action_controller'
require File.join(PLUGIN_ROOT, 'spec/tag_matcher.rb')
require File.join(PLUGIN_ROOT, 'lib/12_hour_time.rb')
require File.join(PLUGIN_ROOT, 'lib/unobtrusive_date_picker.rb')


ActionView::Base.send :include, UnobtrusiveDatePicker::UnobtrusiveDatePickerHelper
ActionView::Helpers::DateHelper.send :include, UnobtrusiveDatePicker::UnobtrusiveDatePickerHelper
ActionView::Base.send :include, UnobtrusiveDatePicker::AssetTagHelper
ActionView::Helpers::AssetTagHelper.send :include, UnobtrusiveDatePicker::AssetTagHelper

ActionController::Base.perform_caching = false
ActionController::Base.consider_all_requests_local = true
ActionController::Base.allow_forgery_protection    = false

def get_meridian_integer(meridian)
  UnobtrusiveDatePicker::DateTimePickerSelector.const_get(meridian.upcase.to_sym)
end

describe "all date picker helpers", :shared => true do
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::UrlHelper
  include ActionView::Helpers::FormTagHelper
  include ActionView::Helpers::FormHelper
  include ActionView::Helpers::DateHelper
  include ActionView::Helpers::ActiveRecordHelper
  include UnobtrusiveDatePicker::UnobtrusiveDatePickerHelper
end

Spec::Runner.configure do |config|
   
   config.include(TagMatcher)
   config.include(SelectorMatcher)
   
   # == Mock Framework
   #
   # RSpec uses it's own mocking framework by default. If you prefer to
   # use mocha, flexmock or RR, uncomment the appropriate line:
   #
   # config.mock_with :mocha
   # config.mock_with :flexmock
   # config.mock_with :rr
   
end
