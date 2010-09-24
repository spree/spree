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

Spree::MailSettings.init

Mail.register_interceptor(Spree::MailInterceptor)

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


String.class_eval do
  include SpreeCore::Ext::String
end