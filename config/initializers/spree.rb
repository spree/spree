# Spree Configuration
SESSION_KEY = '_spree_session_id'
SHIPPING_METHODS = [:flat_rate]
FLAT_SHIPPING_RATE = 10 # applies only to the flat rate shipping option

INVENTORY_STATES = [:on_hand, :sold, :shipped, :back_ordered]

#require 'spree/support/core_ext/array/conversions'

# TODO - Add the lib/plugins stuff maybe?

# Initialize preference system (and attribute_fu)
#
# We need to hand-load attribute_fu stuff here because we call
# ActiveRecord#has_many method before the attribute_fu plugin is
# completely loaded.
ActiveRecord::Base.class_eval do
  include AttributeFu::Associations
  include Spree::Preferences
  include Spree::Preferences::ModelHooks
end

ActionView::Helpers::FormBuilder.class_eval do
  include AttributeFu::AssociatedFormHelper
end


# Initialize mail server settings
Spree::Preferences::MailSettings.init

# Add extra support goodies (similar to rails active support)
#class Array #:nodoc:
#  include Spree::Support::CoreExtensions::Array
#end

class String #:nodoc:
  include Spree::Support::CoreExtensions::String
end

CalendarDateSelect.format = :american
  
