# Add necessary Rails path
#$LOAD_PATH.unshift "#{SPREE_ROOT}/vendor/rails/railties/lib"
#require 'rubygems'
#gem 'rails', '>=2.2.2'

require 'initializer'
require 'spree/extension_loader'

module Spree

  class Configuration < Rails::Configuration
    attr_accessor :extension_paths
    attr_accessor :extensions
    attr_accessor :view_paths

    def initialize   
      self.view_paths = []
      self.extension_paths = default_extension_paths
      self.extensions = [ :all ]
      super
    end

    def default_extension_paths
      env = ENV["RAILS_ENV"] || RAILS_ENV
      paths = [SPREE_ROOT + '/vendor/extensions', RAILS_ROOT + '/vendor/extensions'].uniq
      # There's no other way it will work, config/environments/test.rb loads too late
      # TODO: Should figure out how to include this extension path only for the tests that need it
      paths.unshift(SPREE_ROOT + "/test/fixtures/extensions") if env == "test"
      paths
    end

    private

      def library_directories
        Dir["#{SPREE_ROOT}/vendor/*/lib"]
      end

      def framework_root_path   
        RAILS_ROOT + '/vendor/rails'
      end

      # Provide the load paths for the Spree installation
      def default_load_paths       
        paths = ["#{SPREE_ROOT}/test/mocks/#{environment}"]

        # Add the app's controller directory
        paths.concat(Dir["#{SPREE_ROOT}/app/controllers/"])

        # Then components subdirectories.
        paths.concat(Dir["#{SPREE_ROOT}/components/[_a-z]*"])

        # Followed by the standard includes.
        paths.concat %w(
          app
          app/models
          app/controllers
          app/helpers
          config
          lib
          vendor
        ).map { |dir| "#{SPREE_ROOT}/#{dir}" }.select { |dir| File.directory?(dir) }

        paths.concat builtin_directories
        paths.concat library_directories 
      end

      def default_plugin_paths
        [
          "#{RAILS_ROOT}/vendor/plugins",
          "#{SPREE_ROOT}/lib/plugins",
          "#{SPREE_ROOT}/vendor/plugins"
        ]
      end

      def default_view_path
        File.join(SPREE_ROOT, 'app', 'views')
      end

      def default_controller_paths
        [File.join(SPREE_ROOT, 'app', 'controllers')]
      end
  end

  class Initializer < Rails::Initializer
    def self.run(command = :process, configuration = Configuration.new)
      super
    end

    # If Rails is vendored and RubyGems is available, install stub GemSpecs
    # for Rails, Active Support, Active Record, Action Pack, Action Mailer, and
    # Active Resource. This allows Gem plugins to depend on Rails even when
    # the Gem version of Rails shouldn't be loaded.
    def install_gem_spec_stubs
      #TODO - provide meaningful implementation (commented out for now so we can start server)
    end
        
    def set_autoload_paths
      extension_loader.add_extension_paths
      super
    end

    def add_plugin_load_paths
      # checks for plugins within extensions:
      extension_loader.add_plugin_paths
      super
    end

    def load_plugins
      super
      extension_loader.load_extensions

      # Add extension gems.
      Object.subclasses_of(Spree::Extension).each do |extension_class|
        if extension_class.respond_to? :require_gems
          extension_class.require_gems(@configuration)
        end
      end
    end

    def after_initialize
      extension_loader.activate_extensions unless $rails_gem_installer
      extension_loader.run_initializers #? conds?
      super
    end
=begin
    def initialize_default_admin_tabs
      admin.tabs.clear
      admin.tabs.add "Pages",    "/admin/pages"
      admin.tabs.add "Snippets", "/admin/snippets"
      admin.tabs.add "Layouts",  "/admin/layouts", :visibility => [:admin, :developer]
    end
=end
    def initialize_framework_views
      view_paths = returning [] do |arr|
        # Add the singular view path if it's not in the list
        arr << configuration.view_path if !configuration.view_paths.include?(configuration.view_path)
        # Add the default view paths
        arr.concat configuration.view_paths
        # Add the extension view paths
        arr.concat extension_loader.view_paths     
        # Reverse the list so extensions come first
        arr.reverse!
      end
    
      ActionMailer::Base.template_root = view_paths  if configuration.frameworks.include?(:action_mailer)        
      ActionController::Base.view_paths = view_paths if configuration.frameworks.include?(:action_controller)
    end
    
    def initialize_i18n
      extension_loader.add_locale_paths
      spree_locale_paths = Dir[File.join(SPREE_ROOT, 'config', 'locales', '*.{rb,yml}')]
      extension_loader.configuration.i18n.load_path = spree_locale_paths + extension_loader.configuration.i18n.load_path
      super
    end

    def initialize_routing #BQ - Don't this think method is needed anymore?
      extension_loader.add_controller_paths
      super
    end
=begin
    def admin
      configuration.admin
    end
=end
    def extension_loader
      ExtensionLoader.instance {|l| l.initializer = self }
    end
    
  end

end
