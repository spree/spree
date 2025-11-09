require 'rails/generators'

module Spree
  module Admin
    module Generators
      class DeviseGenerator < Rails::Generators::Base
        desc 'Installs Spree Admin Devise controllers'

        def install
          # add devise routes
          insert_into_file 'config/routes.rb', after: "Rails.application.routes.draw do\n" do
            <<-ROUTES.strip_heredoc.indent!(2)
              Spree::Core::Engine.add_routes do
                # Admin authentication
                devise_for(
                  Spree.admin_user_class.model_name.singular_route_key,
                  class_name: Spree.admin_user_class.to_s,
                  controllers: {
                    sessions: 'spree/admin/user_sessions',
                    passwords: 'spree/admin/user_passwords'
                  },
                  skip: :registrations,
                  path: :admin_user,
                  router_name: :spree
                )
              end
            ROUTES
          end
        end
      end
    end
  end
end
