require 'rails/generators'
require 'highline/import'
require 'bundler'
require 'bundler/cli'

module Spree
  class InstallGenerator < Rails::Generators::Base
    argument :after_bundle_only, :type => :string, :default => "false"

    class_option :auto_accept, :type => :boolean, :default => false, :aliases => '-A', :desc => "Answer yes to all prompts"
    class_option :skip_install_data, :type => :boolean, :default => false
    class_option :lib_name, :default => 'spree'
    class_option :test_app, :type => :boolean, :default => false

    def self.source_paths
      paths = self.superclass.source_paths
      paths << File.expand_path('../templates', "../../#{__FILE__}")
      paths << File.expand_path('../templates', "../#{__FILE__}")
      paths << File.expand_path('../templates', __FILE__)
      paths.flatten
    end

    def ask_questions
      @install_blue_theme = ask_with_default("Would you like to install the default blue theme?")
      @install_default_gateways = ask_with_default("Would you like to install the default gateways?")

      if options[:skip_install_data]
        @run_migrations = false
        @load_seed_data = false
        @load_sample_data = false
      else
        @run_migrations = ask_with_default("Would you like to run the migrations?")
        if @run_migrations
          @load_seed_data = ask_with_default("Would you like to load the seed data?")
          if Rails::Engine::Railties.engines.collect{|c| c.engine_name}.include?('spree_sample')
            @load_sample_data = ask_with_default("Would you like to load the sample data?")
          end
        else
          @load_seed_data = false
          @load_sample_data = false
        end
      end
    end

    def add_files
      template 'config/initializers/spree.rb', 'config/initializers/spree.rb'
    end

    def config_spree_yml
      create_file "config/spree.yml" do
        settings = { 'version' => Spree.version }

        settings.to_yaml
      end
    end

    def remove_unneeded_files
      remove_file "public/index.html"
    end

    def additional_tweaks
      return unless File.exists? 'public/robots.txt'
      append_file "public/robots.txt", <<-ROBOTS
User-agent: *
Disallow: /checkouts
Disallow: /orders
Disallow: /countries
Disallow: /line_items
Disallow: /password_resets
Disallow: /states
Disallow: /user_sessions
Disallow: /users
      ROBOTS
    end

    def create_overrides_directory
      empty_directory "app/overrides"
    end

    def configure_application
      application <<-APP

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

      append_file "config/environment.rb", "\nActiveRecord::Base.include_root_in_json = true\n"
    end

    def install_gems
      return if options[:test_app]
      gems = {}

      if @install_blue_theme
        gems['spree_blue_theme'] = { :git => 'git@github.com:spree/spree_blue_theme.git',
                                     :ref => '10666404ccb3ed4a4cc9cbe41e822ab2bb55112e' }
      end

      if @install_default_gateways
        gems['spree_usa_epay'] = { :git => 'git@github.com:spree/spree_usa_epay.git',
                                   :ref => '395b264118b1a47ee2a2ce7544788cd81a4dd6e3' }

        gems['spree_skrill'] = { :git => 'git@github.com:spree/spree_skrill.git',
                                 :ref => '6743bcbd0146d1c7145d6befc648005d8d0cf79a' }
      end

      unless gems.empty?
        gems.each do |name, options|
          gem name, options
        end
        bundle_command :update
      end
    end

    def include_seed_data
      append_file "db/seeds.rb", <<-SEEDS
\n
Spree::Core::Engine.load_seed if defined?(Spree::Core)
Spree::Auth::Engine.load_seed if defined?(Spree::Auth)
      SEEDS
    end

    def install_migrations
      say_status :copying, "migrations"
      silence_stream(STDOUT) do
        silence_warnings { rake 'railties:install:migrations' }
      end
    end

    def run_migrations
      if @run_migrations
        say_status :running, "migrations"
        rake('db:migrate')
      else
        say_status :skipping, "migrations (don't forget to run rake db:migrate)"
      end
    end

    def populate_seed_data
      if @load_seed_data
        say_status :loading,  "seed data"
        rake('db:seed AUTO_ACCEPT=true')
      else
        say_status :skipping, "seed data (you can always run rake db:seed)"
      end
    end

    def load_sample_data
      if @load_sample_data
        say_status :loading, "sample data"
        rake('spree_sample:load')
      else
        say_status :skipping, "sample data (you can always run rake spree_sample:load)"
      end
    end

    def notify_about_routes
      insert_into_file File.join('config', 'routes.rb'), :after => "Application.routes.draw do\n" do
        "  # Mount Spree's routes\n  mount Spree::Core::Engine, :at => '/'\n"
      end

      unless options[:quiet]
        puts "*" * 50
        puts "We added the following line to your application's config/routes.rb file:"
        puts " "
        puts "    mount Spree::Core::Engine, :at => '/'"
      end
    end

    private

    def ask_with_default(message, default='yes')
      return true if options[:auto_accept]

      valid = false
      until valid
        response = ask "#{message} (y/n) [#{default}]"
        response = default if response.empty?
        valid = (response  =~ /\Ay(?:es)?|no?\Z/i)
      end
      response.downcase[0] == ?y
    end

    # Copied from https://github.com/rails/rails/blob/b1ceffd7b224c397d8ba5344b9c1438dd62f8325/railties/lib/rails/generators/app_base.rb#L189
    def bundle_command(command)
      say_status :run, "bundle #{command}"
      Bundler::CLI.new.send(command)
    end

  end
end
