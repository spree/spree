require 'rails/generators'

module Spree
  class InstallGenerator < Rails::Generators::Base
    class_option :lib_name, type: :string

    def self.source_paths
      superclass.source_paths + [File.join(__dir__, 'templates')]
    end

    def add_files
      template('config/initializers/spree.rb', 'config/initializers/spree.rb')
    end

    def setup_assets
      %w[
        javascripts/spree/frontend/all.js
        stylesheets/spree/frontend/all.css
        javascripts/spree/backend/all.js
        stylesheets/spree/backend/all.css
      ].each do |name|
        template("vendor/assets/#{name}")
      end
    end

    def configure_application
      application(<<-'APP'.strip_heredoc)
        config.to_prepare do
          Dir.glob(File.join(__dir__, '../app/**/*.rb'), &method(:require))
        end
      APP
    end

    def install_migrations
      silence_stream(STDOUT) do
        rake('railties:install:migrations')
      end
    end

    def notify_about_routes
      insert_into_file('config/routes.rb', after: 'Rails.application.routes.draw do') do
        "\nmount Spree::Core::Engine, at: '/'"
      end
    end
  end
end
