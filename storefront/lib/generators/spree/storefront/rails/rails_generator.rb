require 'rails/generators'

module Spree
  module Storefront
    module Generators
      class RailsGenerator < Rails::Generators::Base
        desc 'Installs Spree Storefront Rails 8 authentication controllers and routes'

        def self.source_paths
          [
            File.expand_path('templates', __dir__),
            File.expand_path('../templates', "../#{__FILE__}"),
            File.expand_path('../templates', "../../#{__FILE__}")
          ]
        end

        def check_rails_version
          unless Rails::VERSION::MAJOR >= 8
            say 'Rails 8+ is required for built-in authentication. Please use Devise instead:', :red
            say '  rails generate spree:storefront:devise'
            exit 1
          end
        end

        def create_controllers
          template 'user_sessions_controller.rb.tt', 'app/controllers/spree/user_sessions_controller.rb'
          template 'user_passwords_controller.rb.tt', 'app/controllers/spree/user_passwords_controller.rb'
          template 'user_registrations_controller.rb.tt', 'app/controllers/spree/user_registrations_controller.rb'
        end

        def create_views
          directory 'views/spree/user_sessions', 'app/views/spree/user_sessions'
          directory 'views/spree/user_registrations', 'app/views/spree/user_registrations'
          directory 'views/spree/user_passwords', 'app/views/spree/user_passwords'
        end

        def create_mailer
          template 'user_passwords_mailer.rb.tt', 'app/mailers/spree/user_passwords_mailer.rb'
          directory 'views/spree/user_passwords_mailer', 'app/views/spree/user_passwords_mailer'
        end

        def install_routes
          insert_into_file 'config/routes.rb', after: "Rails.application.routes.draw do\n" do
            <<-ROUTES.strip_heredoc.indent!(2)
              Spree::Core::Engine.add_routes do
                # Storefront authentication (Rails 8 built-in)
                scope '(:locale)', locale: /\#{Spree.available_locales.join('|')\}/, defaults: { locale: nil } do
                  resource :user_session, controller: 'user_sessions', path: 'user/session'
                  resource :user_registration, controller: 'user_registrations', path: 'user/registration'
                  resources :user_passwords, controller: 'user_passwords', param: :token, path: 'user/passwords'
                end
              end
            ROUTES
          end
        end

        def display_post_install_message
          say ''
          say 'Storefront authentication routes installed!', :green
          say ''
          say 'Routes added:'
          say '  GET    /user/session/new       => user_sessions#new      (login)'
          say '  POST   /user/session           => user_sessions#create'
          say '  DELETE /user/session           => user_sessions#destroy  (logout)'
          say '  GET    /user/registration/new  => user_registrations#new (signup)'
          say '  POST   /user/registration      => user_registrations#create'
          say '  GET    /user/passwords/new     => user_passwords#new     (forgot password)'
          say '  POST   /user/passwords         => user_passwords#create'
          say '  GET    /user/passwords/:token/edit => user_passwords#edit'
          say '  PATCH  /user/passwords/:token      => user_passwords#update'
          say ''
        end
      end
    end
  end
end
