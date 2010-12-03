require 'mail'

# Spree Configuration
SESSION_KEY = '_spree_session_id'
#require 'spree/support/core_ext/array/conversions'

# TODO - Add the lib/plugins stuff maybe?

# Initialize preference system
ActiveRecord::Base.class_eval do
  include Spree::Preferences
  include Spree::Preferences::ModelHooks
end

if MailMethod.table_exists?
  Spree::MailSettings.init
  Mail.register_interceptor(Spree::MailInterceptor)
end

# Add extra support goodies (similar to rails active support)
#class Array #:nodoc:
#  include Spree::Support::CoreExtensions::Array
#end

String.class_eval do
  include SpreeCore::Ext::String
end
