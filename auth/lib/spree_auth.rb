require File.expand_path("../../../core/lib/spree_core", __FILE__)
require 'devise'
require 'cancan'

require File.expand_path("../spree/auth/config", __FILE__)
require File.expand_path("../spree/token_resource", __FILE__)
require File.expand_path("../spree_auth_hooks", __FILE__)

module SpreeAuth
  class Engine < Rails::Engine
    engine_name 'spree_auth'

    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), "../app/**/*_decorator*.rb")) do |c|
        Rails.env.production? ? require(c) : load(c)
      end

      # monkey patch until new version of devise comes out
      # https://github.com/plataformatec/devise/commit/ec5bfe9119d0e1e633629793b0de1f58f89622dc
      # Devise::IndifferentHash.class_eval do
      #   def [](key)
      #     super(convert_key(key))
      #   end
      #   def to_hash; Hash.new.update(self) end
      # end
    end

    config.to_prepare &method(:activate).to_proc
    ActiveRecord::Base.class_eval { include Spree::TokenResource }
  end
end
