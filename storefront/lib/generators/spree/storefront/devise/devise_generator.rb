require 'rails/generators'

module Spree
  module Storefront
    module Generators
      class DeviseGenerator < Rails::Generators::Base
        desc 'Installs Spree Storefront Devise controllers'

        def self.source_paths
          [
            File.expand_path('templates', __dir__),
            File.expand_path('../templates', "../#{__FILE__}"),
            File.expand_path('../templates', "../../#{__FILE__}")
          ]
        end

        def install
          template 'user_sessions_controller.rb', 'app/controllers/spree/user_sessions_controller.rb'
          template 'user_registrations_controller.rb', 'app/controllers/spree/user_registrations_controller.rb'
          template 'user_passwords_controller.rb', 'app/controllers/spree/user_passwords_controller.rb'

          # add devise routes
          insert_into_file 'config/routes.rb', after: "Rails.application.routes.draw do\n" do
            <<-ROUTES.strip_heredoc.indent!(2)
              Spree::Core::Engine.add_routes do
                # Storefront routes
                scope '(:locale)', locale: /\#{Spree.available_locales.join('|')\}/, defaults: { locale: nil } do
                  devise_for(
                    Spree.user_class.model_name.singular_route_key,
                    class_name: Spree.user_class.to_s,
                    path: :user,
                    controllers: {
                      sessions: 'spree/user_sessions',
                      passwords: 'spree/user_passwords',
                      registrations: 'spree/user_registrations'
                    },
                    router_name: :spree
                  )
                end
              end
            ROUTES
          end
        end
      end
    end
  end
end
