# Spree Configuration
SESSION_KEY = '_spree_session_id'

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

#RAILS3 TODO
# class ActiveRecord::Base
#   # Ryan Bates - http://railscasts.com/episodes/112
#   scope :conditions, lambda { |*args| where(args)}
# 
#   # general merging of conditions, names following the searchlogic pattern
#   # conditions_all is a more descriptively named enhancement of the above
#   scope :conditions_all, lambda { |*args| where([args].flatten)}
# 
#   # forming the disjunction of a list of conditions (as strings)
#   scope :conditions_any, lambda { |*args| 
#     args = [args].flatten
#     raise "non-strings in conditions_any" unless args.all? {|s| s.is_a? String}
#     { where(args.map {|c| "(#{c})"}.join(" OR ")) }
#   }
# end


class String #:nodoc:
  include Spree::Support::CoreExtensions::String
end

require 'spree/theme_support'
require 'state_machine'
require 'stringex'
require 'will_paginate'
require 'openid'
