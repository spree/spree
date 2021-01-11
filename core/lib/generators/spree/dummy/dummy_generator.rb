require 'rails/generators/rails/app/app_generator'
require 'active_support/core_ext/hash'
require 'spree/core/version'

module Spree
  class DummyGenerator < Rails::Generators::Base
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
      opts[:skip_gemfile] = true
      opts[:skip_git] = true
      opts[:skip_keeps] = true
      opts[:skip_listen] = true
      opts[:skip_rc] = true
      opts[:skip_spring] = true
      opts[:skip_test] = true
      opts[:skip_yarn] = true
      opts[:skip_javascript] = true
      opts[:skip_bootsnap] = true

      puts 'Generating dummy Rails application...'
      invoke Rails::Generators::AppGenerator,
        [File.expand_path(dummy_path, destination_root)], opts
    end

    def test_dummy_config
      @lib_name = options[:lib_name]
      @database = options[:database]

      template 'rails/database.yml', "#{dummy_path}/config/database.yml", force: true
      template 'rails/boot.rb', "#{dummy_path}/config/boot.rb", force: true
      template 'rails/application.rb', "#{dummy_path}/config/application.rb", force: true
      template 'rails/routes.rb', "#{dummy_path}/config/routes.rb", force: true
      template 'rails/test.rb', "#{dummy_path}/config/environments/test.rb", force: true
      template 'rails/script/rails', "#{dummy_path}/spec/dummy/script/rails", force: true
      template 'initializers/devise.rb', "#{dummy_path}/config/initializers/devise.rb", force: true
      template 'initializers/bullet.rb', "#{dummy_path}/config/initializers/bullet.rb", force: true
    end

    def test_dummy_inject_extension_requirements
      if DummyGeneratorHelper.inject_extension_requirements
        inside dummy_path do
          inject_require_for('spree_frontend')
          inject_require_for('spree_backend')
          inject_require_for('spree_api')
        end
      end
    end

    def test_dummy_clean
      inside dummy_path do
        remove_file '.gitignore'
        remove_file 'doc'
        remove_file 'Gemfile'
        remove_file 'lib/tasks'
        remove_file 'app/assets/images/rails.png'
        remove_file 'app/assets/javascripts/application.js'
        remove_file 'public/index.html'
        remove_file 'public/robots.txt'
        remove_file 'README'
        remove_file 'test'
        remove_file 'vendor'
        remove_file 'spec'
      end
    end

    def inject_content_security_policy
      inside dummy_path do
        inject_into_file 'config/initializers/content_security_policy.rb', %Q[
  p.script_src  :self, :https, :unsafe_inline, :http, :unsafe_eval
        ], before: /^end/, verbose: true
      end
    end

    attr_reader :lib_name
    attr_reader :database

    protected

    def inject_require_for(requirement)
      inject_into_file 'config/application.rb', %Q[
begin
  require '#{requirement}'
rescue LoadError
  # #{requirement} is not available.
end
      ], before: /require '#{@lib_name}'/, verbose: true
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

    def camelized
      @camelized ||= name.gsub(/\W/, '_').squeeze('_').camelize
    end

    def remove_directory_if_exists(path)
      remove_dir(path) if File.directory?(path)
    end

    def gemfile_path
      core_gems = ['spree/core', 'spree/api', 'spree/backend', 'spree/frontend', 'spree/sample']

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
