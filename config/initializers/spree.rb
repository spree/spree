require 'spree/support/core_ext/array/conversions'

# TODO - Add the lib/plugins stuff maybe?

ActiveRecord::Base.send :include, Spree::Preferences
ActiveRecord::Base.send :include, Spree::Preferences::ModelHooks
Spree::Preferences::MailSettings.init

# Add extra support goodies (similar to rails active support)
class Array #:nodoc:
  include Spree::Support::CoreExtensions::Array::Conversions
end