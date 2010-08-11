require 'spree_core'
require 'spree_api_hooks'

module SpreeApi
  class Engine < Rails::Engine
    def self.activate
      lambda{

        Admin::UsersController.class_eval do

          def generate_api_key
            if object.generate_api_key!
              flash.notice = t('api.key_generated')
            end
            redirect_to edit_object_path
          end

        end

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

        LineItem.class_eval do
          def description
            d = variant.product.name.clone
            d << " (#{variant.options_text})" unless variant.option_values.empty?
            d
          end
        end
      }
    end
    config.autoload_paths += %W(#{config.root}/lib)
    config.to_prepare &self.activate
  end
end