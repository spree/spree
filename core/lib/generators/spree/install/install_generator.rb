require 'rails/generators'
require 'highline/import'
require 'bundler'
require 'bundler/cli'
require 'active_support/core_ext/string/indent'
require 'spree/core'

module Spree
  class InstallGenerator < Rails::Generators::Base
    class_option :migrate, type: :boolean, default: true, banner: 'Run Spree migrations'
    class_option :seed, type: :boolean, default: true, banner: 'load seed data (migrations must be run)'
    class_option :sample, type: :boolean, default: true, banner: 'load sample data (migrations must be run)'
    class_option :copy_views, type: :boolean, default: true, banner: 'copy frontend views from spree to your application for easy customization'
    class_option :auto_accept, type: :boolean
    class_option :user_class, type: :string
    class_option :admin_email, type: :string
    class_option :admin_password, type: :string
    class_option :lib_name, type: :string, default: 'spree'
    class_option :enforce_available_locales, type: :boolean, default: nil

    def self.source_paths
      paths = superclass.source_paths
      paths << File.expand_path('../templates', "../../#{__FILE__}")
      paths << File.expand_path('../templates', "../#{__FILE__}")
      paths << File.expand_path('../templates', __FILE__)
      paths.flatten
    end

    def prepare_options
      @run_migrations = options[:migrate]
      @load_seed_data = options[:seed]
      @load_sample_data = options[:sample]
      @copy_views = options[:copy_views]

      unless @run_migrations
        @load_seed_data = false
        @load_sample_data = false
      end
    end

    def add_files
      template 'config/initializers/spree.rb', 'config/initializers/spree.rb'
    end

    def additional_tweaks
      return unless File.exist? 'public/robots.txt'
      append_file 'public/robots.txt', <<-ROBOTS.strip_heredoc
        User-agent: *
        Disallow: /checkout
        Disallow: /cart
        Disallow: /orders
        Disallow: /user
        Disallow: /account
        Disallow: /api
        Disallow: /password
      ROBOTS
    end

    def setup_assets
      @lib_name = 'spree'
      %w{javascripts stylesheets images}.each do |path|
        if Spree::Core::Engine.frontend_available? || Rails.env.test?
          empty_directory "vendor/assets/#{path}/spree/frontend"
        end
        if Spree::Core::Engine.backend_available? || Rails.env.test?
          empty_directory "vendor/assets/#{path}/spree/backend"
        end
      end

      if Spree::Core::Engine.frontend_available? || Rails.env.test?
        template 'vendor/assets/javascripts/spree/frontend/all.js'
        template 'vendor/assets/stylesheets/spree/frontend/all.css'
      end

      if Spree::Core::Engine.backend_available? || Rails.env.test?
        template 'vendor/assets/javascripts/spree/backend/all.js'
        template 'vendor/assets/stylesheets/spree/backend/all.css'
      end
    end

    def create_overrides_directory
      empty_directory 'app/overrides'
    end

    def copy_views
      if @copy_views && Spree::Core::Engine.frontend_available?
        generate 'spree:frontend:copy_views'
      end
    end

    def configure_application
      application <<-APP.strip_heredoc.indent!(4)

        config.to_prepare do
          # Load application's model / class decorators
          Dir.glob(File.join(File.dirname(__FILE__), "../app/**/*_decorator*.rb")) do |c|
            Rails.configuration.cache_classes ? require(c) : load(c)
          end

          # Load application's view overrides
          Dir.glob(File.join(File.dirname(__FILE__), "../app/overrides/*.rb")) do |c|
            Rails.configuration.cache_classes ? require(c) : load(c)
          end
        end
      APP

      unless options[:enforce_available_locales].nil?
        application <<-APP.strip_heredoc.indent!(4)
          # Prevent this deprecation message: https://github.com/svenfuchs/i18n/commit/3b6e56e
          I18n.enforce_available_locales = #{options[:enforce_available_locales]}
        APP
      end
    end

    def include_seed_data
      append_file 'db/seeds.rb', <<-SEEDS.strip_heredoc

        Spree::Core::Engine.load_seed if defined?(Spree::Core)
        Spree::Auth::Engine.load_seed if defined?(Spree::Auth)
      SEEDS
    end

    def install_migrations
      say_status :copying, 'migrations'
      silence_stream(STDOUT) do
        silence_warnings { rake 'railties:install:migrations' }
      end
    end

    def create_database
      say_status :creating, 'database'
      silence_stream(STDOUT) do
        silence_stream(STDERR) do
          silence_warnings { rake 'db:create' }
        end
      end
    end

    def run_migrations
      if @run_migrations
        say_status :running, 'migrations'
        silence_stream(STDOUT) do
          silence_stream(STDERR) do
            silence_warnings { rake 'db:migrate' }
          end
        end
      else
        say_status :skipping, "migrations (don't forget to run rake db:migrate)"
      end
    end

    def populate_seed_data
      if @load_seed_data
        say_status :loading,  'seed data'
        rake_options = []
        rake_options << 'AUTO_ACCEPT=1' if options[:auto_accept]
        rake_options << "ADMIN_EMAIL=#{options[:admin_email]}" if options[:admin_email]
        rake_options << "ADMIN_PASSWORD=#{options[:admin_password]}" if options[:admin_password]

        cmd = -> { rake("db:seed #{rake_options.join(' ')}") }
        if options[:auto_accept] || (options[:admin_email] && options[:admin_password])
          silence_stream(STDOUT) do
            silence_stream(STDERR) do
              silence_warnings &cmd
            end
          end
        else
          cmd.call
        end
      else
        say_status :skipping, 'seed data (you can always run rake db:seed)'
      end
    end

    def load_sample_data
      if @load_sample_data
        say_status :loading, 'sample data'
        silence_stream(STDOUT) do
          silence_stream(STDERR) do
            silence_warnings { rake 'spree_sample:load' }
          end
        end
      else
        say_status :skipping, 'sample data (you can always run rake spree_sample:load)'
      end
    end

    def notify_about_routes
      insert_into_file(File.join('config', 'routes.rb'),
                       after: "Rails.application.routes.draw do\n") do
        <<-ROUTES.strip_heredoc.indent!(2)
          # This line mounts Spree's routes at the root of your application.
          # This means, any requests to URLs such as /products, will go to
          # Spree::ProductsController.
          # If you would like to change where this engine is mounted, simply change the
          # :at option to something different.
          #
          # We ask that you don't use the :as option here, as Spree relies on it being
          # the default of "spree".
          mount Spree::Core::Engine, at: '/'
        ROUTES
      end

      unless options[:quiet]
        puts '*' * 50
        puts "We added the following line to your application's config/routes.rb file:"
        puts ' '
        puts "    mount Spree::Core::Engine, at: '/'"
      end
    end

    def complete
      unless options[:quiet]
        puts '*' * 50
        puts "Spree has been installed successfully. You're all ready to go!"
        puts ' '
        puts 'Enjoy!'
      end
    end

    protected

    def javascript_exists?(script)
      extensions = %w(.js.coffee .js.erb .js.coffee.erb .js)
      file_exists?(extensions, script)
    end

    def stylesheet_exists?(stylesheet)
      extensions = %w(.css.scss .css.erb .css.scss.erb .css)
      file_exists?(extensions, stylesheet)
    end

    def file_exists?(extensions, filename)
      extensions.detect do |extension|
        File.exist?("#{filename}#{extension}")
      end
    end

    private

    def silence_stream(stream)
      old_stream = stream.dup
      stream.reopen(RbConfig::CONFIG['host_os'] =~ /mswin|mingw/ ? 'NUL:' : '/dev/null')
      stream.sync = true
      yield
    ensure
      stream.reopen(old_stream)
      old_stream.close
    end
  end
end
