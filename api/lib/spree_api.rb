require 'spree_core'
require 'spree_api_hooks'

module SpreeApi
  class Engine < Rails::Engine
    def self.activate

      # RAILS3 TODO: Get the API stuff working with Devise
      # Spree::BaseController.class_eval do
      #   private
      #   def current_user
      #     return @current_user if defined?(@current_user)
      #     if current_user_session && current_user_session.user
      #       return @current_user = current_user_session.user
      #     end
      #     if token = request.headers['X-SpreeAPIKey']
      #       @current_user = User.find_by_api_key(token)
      #     end
      #   end
      # end

    end
    config.autoload_paths += %W(#{config.root}/lib)
    config.to_prepare &self.activate
  end
end