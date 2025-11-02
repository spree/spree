require 'rails/generators/rails/app/app_generator'
require 'active_support/core_ext/hash'
require 'spree/core/version'

module Spree
  class DummyGenerator < Rails::Generators::Base
    SPREE_GEMS = %w(spree_admin spree_storefront spree_api spree_emails).freeze

    desc 'Creates blank Rails application, installs Spree and all sample data'

    class_option :lib_name, default: ''
    class_option :database, default: ''

    def self.source_paths
      paths = superclass.source_paths
      paths << File.expand_path('templates', __dir__)
      paths.flatten
    end

    def clean_up
      remove_directory_if_exists(dummy_path)
    end

    PASSTHROUGH_OPTIONS = [
      :skip_active_record, :skip_javascript, :database, :javascript, :quiet, :pretend, :force, :skip
    ]

    def generate_test_dummy
      # calling slice on a Thor::CoreExtensions::HashWithIndifferentAccess
      # object has been known to return nil
      opts = {}.merge(options).slice(*PASSTHROUGH_OPTIONS)
      opts[:database] = 'sqlite3' if opts[:database].blank?
      opts[:force] = true
      opts[:skip_bundle] = true
      opts[:skip_git] = true
      opts[:skip_listen] = true
      opts[:skip_rc] = true
      opts[:skip_spring] = true
      opts[:skip_test] = true
      opts[:skip_bootsnap] = true
      opts[:skip_docker] = true
      opts[:skip_rubocop] = true
      opts[:skip_brakeman] = true
      opts[:skip_ci] = true
      opts[:skip_kamal] = true
      opts[:skip_devcontainer] = true
      opts[:skip_solid] = true

      puts 'Generating dummy Rails application...'
      invoke Rails::Generators::AppGenerator,
        [File.expand_path(dummy_path, destination_root)], opts
      inject_yaml_permitted_classes
    end

    def test_dummy_config
      @lib_name = options[:lib_name]
      @database = options[:database]

      template 'rails/database.yml', "#{dummy_path}/config/database.yml", force: true
      template 'rails/boot.rb', "#{dummy_path}/config/boot.rb", force: true
      template 'rails/application.rb', "#{dummy_path}/config/application.rb", force: true
      template 'rails/routes.rb', "#{dummy_path}/config/routes.rb", force: true
      template 'rails/test.rb', "#{dummy_path}/config/environments/test.rb", force: true
      template 'initializers/devise.rb', "#{dummy_path}/config/initializers/devise.rb", force: true
      template "app/assets/config/manifest.js", "#{dummy_path}/app/assets/config/manifest.js", force: true
    end

    def test_dummy_inject_extension_requirements
      if DummyGeneratorHelper.inject_extension_requirements
        SPREE_GEMS.each do |gem|
          begin
            require "#{gem}"
            inside dummy_path do
              inject_require_for(gem)
            end
          rescue StandardError, LoadError
          end
        end
      end
    end

    attr_reader :lib_name
    attr_reader :database

    protected

    def inject_yaml_permitted_classes
      inside dummy_path do
        inject_into_file 'config/application.rb', %Q[
    config.active_record.yaml_column_permitted_classes = [Symbol, BigDecimal, ActiveSupport::HashWithIndifferentAccess]
        ], after: /config\.load_defaults.*$/, verbose: true
      end
    end

    def dummy_path
      ENV['DUMMY_PATH'] || 'spec/dummy'
    end

    def module_name
      'Dummy'
    end

    def application_definition
      @application_definition ||= begin
        dummy_application_path = File.expand_path("#{dummy_path}/config/application.rb", destination_root)
        unless options[:pretend] || !File.exist?(dummy_application_path)
          contents = File.read(dummy_application_path)
          contents[(contents.index("module #{module_name}"))..-1]
        end
      end
    end
    alias store_application_definition! application_definition

    def remove_directory_if_exists(path)
      remove_dir(path) if File.directory?(path)
    end

    def gemfile_path
      core_gems = ['spree/core', 'spree/api']

      if core_gems.include?(lib_name)
        '../../../../../Gemfile'
      else
        '../../../../Gemfile'
      end
    end
  end
end

module Spree::DummyGeneratorHelper
  mattr_accessor :inject_extension_requirements
  self.inject_extension_requirements = false
end
