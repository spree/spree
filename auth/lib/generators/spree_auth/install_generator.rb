module SpreeAuth
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("../../templates", __FILE__)

      desc "Configures your Rails application for use with spree_auth."

      def setup_routes
        route 'devise_for :users'
      end

      def copy_initializer
        template "devise.rb", "config/initializers/devise.rb"
      end

      # def show_readme
      #   readme "README" if behavior == :invoke
      # end
    end
  end
end