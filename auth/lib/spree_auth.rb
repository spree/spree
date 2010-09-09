require 'spree_core'
require 'authlogic'
require 'cancan'

require 'spree/auth_user'
require 'spree/auth/config'

module SpreeAuth
  class Engine < Rails::Engine
    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), "../app/**/*_decorator*.rb")) do |c|
        Rails.env == "production" ? require(c) : load(c)
      end
    end
    config.to_prepare &method(:activate).to_proc
  end
end
