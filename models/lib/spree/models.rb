require 'rails/all'
require 'state_machine'
require 'paperclip'
require 'kaminari'
require 'awesome_nested_set'
require 'acts_as_list'
require 'active_merchant'
require 'ransack'

module Spree

  mattr_accessor :user_class

  def self.user_class
    if @@user_class.is_a?(Class)
      raise "Spree.user_class MUST be a String object, not a Class object."
    elsif @@user_class.is_a?(String)
      @@user_class.constantize
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

require 'spree/models/version'
require 'spree/models/engine'

require 'spree/models/delegate_belongs_to'
require 'spree/models/ext/active_record'
require 'spree/models/permalinks'
require 'spree/models/token_resource'
require 'spree/models/calculated_adjustments'

ActiveRecord::Base.class_eval do
  include CollectiveIdea::Acts::NestedSet
end
