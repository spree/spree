require 'spree_core'
require 'devise'
require 'cancan'

require 'spree/auth/config'
require 'spree/token_resource'

module SpreeAuth
  class Engine < Rails::Engine
    engine_name 'spree_auth'

    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), "../app/**/*_decorator*.rb")) do |c|
        Rails.env.production? ? require(c) : load(c)
      end

      Dir.glob(File.join(File.dirname(__FILE__), "../app/overrides/*.rb")) do |c|
        Rails.application.config.cache_classes ? require(c) : load(c)
      end
    end

    config.to_prepare &method(:activate).to_proc
    ActiveRecord::Base.class_eval { include Spree::TokenResource }
  end
end
