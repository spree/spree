require 'rails/all'
require 'active_merchant'
require 'acts_as_list'
require 'awesome_nested_set'
require 'cancan'
require 'kaminari'
require 'mail'
require 'monetize'
require 'paperclip'
require 'paranoia'
require 'ransack'
require 'state_machine'

module Spree

  mattr_accessor :user_class

  def self.user_class
    if @@user_class.is_a?(Class)
      raise "Spree.user_class MUST be a String or Symbol object, not a Class object."
    elsif @@user_class.is_a?(String) || @@user_class.is_a?(Symbol)
      @@user_class.to_s.constantize
    end
  end

  # Used to configure Spree.
  #
  # Example:
  #
  #   Spree.config do |config|
  #     config.site_name = "An awesome Spree site"
  #   end
  #
  # This method is defined within the core gem on purpose.
  # Some people may only wish to use the Core part of Spree.
  def self.config(&block)
    yield(Spree::Config)
  end
end

require 'spree/core/version'
require 'spree/core/engine'

require 'spree/i18n'
require 'spree/money'
require 'spree/promo/coupon_applicator'

require 'spree/core/delegate_belongs_to'
require 'spree/core/ext/active_record'
require 'spree/core/permalinks'
require 'spree/core/token_resource'
require 'spree/core/calculated_adjustments'
require 'spree/core/product_duplicator'

ActiveRecord::Base.class_eval do
  include CollectiveIdea::Acts::NestedSet
end

# Monkey patch to give us miliseconds precision in timestamps
module ActiveSupport
  class TimeWithZone
    # Coerces time to a string for JSON encoding. The default format is ISO 8601. You can get
    # %Y/%m/%d %H:%M:%S +offset style by setting <tt>ActiveSupport::JSON::Encoding.use_standard_json_time_format</tt>
    # to false.
    #
    # ==== Examples
    #
    #   # With ActiveSupport::JSON::Encoding.use_standard_json_time_format = true
    #   Time.utc(2005,2,1,15,15,10).in_time_zone.to_json
    #   # => "2005-02-01T15:15:10.001Z"
    #
    #   # With ActiveSupport::JSON::Encoding.use_standard_json_time_format = false
    #   Time.utc(2005,2,1,15,15,10).in_time_zone.to_json
    #   # => "2005/02/01 15:15:10 +0000"
    #
    def as_json(options = nil)
      if ActiveSupport::JSON::Encoding.use_standard_json_time_format
        xmlschema(3)
      else
        %(#{time.strftime("%Y/%m/%d %H:%M:%S")} #{formatted_offset(false)})
      end
    end
  end
end
