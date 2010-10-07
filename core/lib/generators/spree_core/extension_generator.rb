require 'rails/generators'

module SpreeCore
  module Generators
    class ExtensionGenerator < Rails::Generators::NamedBase
      source_root File.expand_path("../../templates", __FILE__)

      desc "Creates a new extension with the name you specify."
      check_class_collision

      def create_root_files
        empty_directory file_name
        template "LICENSE", "#{file_name}/LICENSE"
        template "Rakefile.tt", "#{file_name}/Rakefile"
        template "README.md", "#{file_name}/README.md"
        template ".gitignore", "#{file_name}/.gitignore"
        template "extension.gemspec.tt", "#{file_name}/#{file_name.dasherize}.gemspec"
      end

      def create_app_dirs
        empty_directory extension_dir('app')
        empty_directory extension_dir('app/controllers')
        empty_directory extension_dir('app/helpers')
        empty_directory extension_dir('app/models')
        empty_directory extension_dir('app/views')
      end

      def create_config_files
        directory "config", "#{file_name}/config"
        #empty_directory extension_dir('config/initializers')
      end

      def create_lib_files
        directory "lib", "#{file_name}/lib"
        template 'extension/extension.rb.tt', "#{file_name}/lib/#{file_name}.rb"
      end

      def update_gemfile
        gem file_name.dasherize, :path => file_name, :require => file_name
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