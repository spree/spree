require 'spree_core'
require 'authlogic'
require 'cancan'

require 'spree/auth_user'
require 'spree/auth/config'


# Overrides the default current_ability method used by Cancan so that we can use the guest_token in addition to current_user.
module CancanAbilityHack
  module ClassMethods
    def current_ability
      @current_ability ||= ::Ability.new(auth_user)
    end
  end
  def self.included(base)
    base.class_eval do
      extend ClassMethods
      class << self
        alias :original_current_ability :current_ability
      end
    end
  end
end

module SpreeAuth
  class Engine < Rails::Engine
    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), "../app/**/*_decorator*.rb")) do |c|
        Rails.env == "production" ? require(c) : load(c)
      end

      ActionController::Base.send :include, CancanAbilityHack
    end
    config.to_prepare &method(:activate).to_proc
  end
end
