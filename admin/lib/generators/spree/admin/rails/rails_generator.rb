require 'rails/generators'

module Spree
  module Admin
    module Generators
      class RailsGenerator < Rails::Generators::Base
        desc 'Installs Spree Admin Rails 8 authentication controllers and routes'

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
            say '  rails generate spree:admin:devise'
            exit 1
          end
        end

        def create_controllers
          template 'admin_sessions_controller.rb.tt', 'app/controllers/spree/admin/sessions_controller.rb'
          template 'admin_passwords_controller.rb.tt', 'app/controllers/spree/admin/passwords_controller.rb'
        end

        def create_views
          directory 'views/spree/admin/sessions', 'app/views/spree/admin/sessions'
          directory 'views/spree/admin/passwords', 'app/views/spree/admin/passwords'
        end

        def create_mailer
          template 'admin_passwords_mailer.rb.tt', 'app/mailers/spree/admin/passwords_mailer.rb'
          directory 'views/spree/admin/passwords_mailer', 'app/views/spree/admin/passwords_mailer'
        end

        def install_routes
          insert_into_file 'config/routes.rb', after: "Rails.application.routes.draw do\n" do
            <<-ROUTES.strip_heredoc.indent!(2)
              Spree::Core::Engine.add_routes do
                # Admin authentication (Rails 8 built-in)
                scope :admin do
                  resource :session, controller: 'admin/sessions', as: :admin_session
                  resources :passwords, controller: 'admin/passwords', param: :token, as: :admin_passwords
                end
              end
            ROUTES
          end
        end

        def display_post_install_message
          say ''
          say 'Admin authentication routes installed!', :green
          say ''
          say 'Routes added:'
          say '  GET    /admin/session/new     => admin/sessions#new'
          say '  POST   /admin/session         => admin/sessions#create'
          say '  DELETE /admin/session         => admin/sessions#destroy'
          say '  GET    /admin/passwords/new   => admin/passwords#new'
          say '  POST   /admin/passwords       => admin/passwords#create'
          say '  GET    /admin/passwords/:token/edit => admin/passwords#edit'
          say '  PATCH  /admin/passwords/:token      => admin/passwords#update'
          say ''
        end
      end
    end
  end
end
