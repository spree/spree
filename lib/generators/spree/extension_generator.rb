require 'rails/generators'

module Spree
  module Generators
    class ExtensionGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("../../templates", __FILE__)

      desc "Creates a new extension with the name you specify."
      check_class_collision

      def create_root_files
        empty_directory file_name
        empty_directory "#{file_name}/config"
        empty_directory "#{file_name}/db"
        empty_directory "#{file_name}/public"
        template "LICENSE", "#{file_name}/LICENSE"
        template "Rakefile.tt", "#{file_name}/Rakefile"
        template "README.md", "#{file_name}/README.md"
        template "gitignore.tt", "#{file_name}/.gitignore"
        template "extension.gemspec.tt", "#{file_name}/#{file_name}.gemspec"
      end

      def config_routes
        template "routes.rb", "#{file_name}/config/routes.rb"
      end

      def install_rake
        template "install.rake.tt", "#{file_name}/lib/tasks/install.rake"
      end

      def create_app_dirs
        empty_directory extension_dir('app')
        empty_directory extension_dir('app/controllers')
        empty_directory extension_dir('app/helpers')
        empty_directory extension_dir('app/models')
        empty_directory extension_dir('app/views')
        empty_directory extension_dir('spec')
      end

      def create_lib_files
        directory "lib", "#{file_name}/lib"
        template 'extension/extension.rb.tt', "#{file_name}/lib/#{file_name}.rb"
        template 'hooks.rb.tt', "#{file_name}/lib/#{file_name}_hooks.rb"
      end

      def create_spec_helper
        template "spec_helper.rb", "#{file_name}/spec/spec_helper.rb"
      end

      def update_gemfile
        gem file_name, :path => file_name, :require => file_name
      end

      protected

      def current_locale
        I18n.locale.to_s
      end

      def extension_dir(join=nil)
        if join
          File.join(file_name, join)
        else
          file_name
        end
      end

    end
  end
end