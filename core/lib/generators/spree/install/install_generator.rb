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
    class_option :sample, type: :boolean, default: false, banner: 'load sample data (migrations must be run)'
    class_option :install_storefront, type: :boolean, default: false, banner: 'installs default rails storefront'
    class_option :install_admin, type: :boolean, default: false, banner: 'installs default rails admin'
    class_option :auto_accept, type: :boolean
    class_option :user_class, type: :string
    class_option :admin_user_class, type: :string
    class_option :admin_email, type: :string
    class_option :admin_password, type: :string
    class_option :lib_name, type: :string, default: 'spree'
    class_option :enforce_available_locales, type: :boolean, default: nil
    class_option :authentication, type: :string, default: 'devise'

    def self.source_paths
      paths = superclass.source_paths
      paths << File.expand_path('../templates', "../../#{__FILE__}")
      paths << File.expand_path('../templates', "../#{__FILE__}")
      paths << File.expand_path('templates', __dir__)
      paths.flatten
    end

    def prepare_options
      @run_migrations = options[:migrate]
      @load_seed_data = options[:seed]
      @load_sample_data = options[:sample]
      @install_storefront = options[:install_storefront]
      @install_admin = options[:install_admin]
      @authentication = options[:authentication]

      unless @run_migrations
        @load_seed_data = false
        @load_sample_data = false
      end
    end

    def add_files
      template 'config/initializers/spree.rb', 'config/initializers/spree.rb'
    end

    # Currently we only support devise, in the future we will also add support for default Rails authentication
    def install_authentication
      if @authentication == 'devise'
        generate 'spree:authentication:devise'
      elsif @authentication == 'dummy'
        # this is for dummy / test app
      end
    end

    def install_storefront
      if @install_storefront && Spree::Core::Engine.frontend_available?
        generate 'spree:storefront:install'

        # generate devise controllers if authentication is devise
        if @authentication == 'devise'
          generate 'spree:storefront:devise'
        end
      end
    end

    def install_admin
      if @install_admin && Spree::Core::Engine.admin_available?
        generate 'spree:admin:install'

        # generate devise controllers if authentication is devise
        if @authentication == 'devise'
          generate 'spree:admin:devise'
        end
      end
    end

    def configure_application
      application <<-APP.strip_heredoc.indent!(4)

        config.to_prepare do
          # Load application's model / class decorators
          Dir.glob(File.join(File.dirname(__FILE__), "../app/**/*_decorator*.rb")) do |c|
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
      SEEDS
    end

    def install_migrations
      say_status :copying, 'migrations'
      silence_stream(STDOUT) do
        silence_warnings { rake 'active_storage:install:migrations' }
        silence_warnings { rake 'action_text:install:migrations' }
        silence_warnings { rake 'spree:install:migrations' }
        silence_warnings { rake 'spree_api:install:migrations' }
      end
    end

    def run_migrations
      if @run_migrations
        say_status :running, 'migrations'
        rake 'db:migrate'
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
          silence_warnings &cmd
        else
          cmd.call
        end
      else
        say_status :skipping, 'seed data (you can always run bin/rails db:seed)'
      end
    end

    def load_sample_data
      return unless Spree::Core::Engine.sample_available?

      if @load_sample_data
        say_status :loading, 'sample data'
        rake 'spree_sample:load'
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
