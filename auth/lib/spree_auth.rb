require 'spree_core'

require 'devise'
require 'devise/orm/active_record'
require 'cancan'

require 'spree/auth_user'
require 'spree/auth/config'

module SpreeAuth
  class Engine < Rails::Engine
    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), "../app/**/*_decorator*.rb")) do |c|
        Rails.env == "production" ? require(c) : load(c)
      end

      # force devise to you the spree_application layout
      ApplicationController.class_eval do
        layout :layout_by_resource

        def layout_by_resource
          if devise_controller?
            "devise"
          else
            "application"
          end
        end
      end

    end
    config.to_prepare &method(:activate).to_proc
  end
end
