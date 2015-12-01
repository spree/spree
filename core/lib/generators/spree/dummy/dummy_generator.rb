require 'rails/generators'
require 'rails/generators/rails/app/app_generator'
require 'active_support/core_ext/kernel/reporting'
require 'ice_nine'

module Spree
  # @api private
  class DummyGenerator < Rails::Generators::Base
    class_option :dummy_path, type: :string

    # Turn array of strings into array of pathnames
    #
    # @param [Array<String>]
    #
    # @return [Array<Pathname>]
    #
    # @api private
    def self.pathnames(input)
      IceNine.deep_freeze(input.map(&Pathname.method(:new)))
    end
    private_class_method :pathnames

    REMOVE_DUMMY_FILES = pathnames(%w[
      .gitignore
      Gemfile
      README.rdoc
      app/assets/images/rails.png
      app/assets/javascripts/application.js
      bin
      config/application.rb
      config/database.yml
      config/environments/development.rb
      config/environments/production.rb
      config/environments/test.rb
      db/seeds.rb
      doc
      lib/tasks
      public/favicon.ico
      public/index.html
      public/robots.txt
      spec
      test
      vendor
    ])

    COPY_FILES = pathnames(%w[
      config/application.rb
      config/environments/test.rb
      config/initializers/spree.rb
      vendor/assets/javascripts/spree/backend/all.js
      vendor/assets/javascripts/spree/frontend/all.js
      vendor/assets/stylesheets/spree/backend/all.css
      vendor/assets/stylesheets/spree/frontend/all.css
    ])

    private_constant(*constants(false))

    # Template source paths
    #
    # @return [Array<String>]
    def self.source_paths
      superclass.source_paths + [File.join(__dir__, 'files')]
    end

    # Initialize object
    #
    # @return [undefined]
    def initialize(*)
      super
      @destination_stack.replace([dummy_path.to_path])
    end

    # Cleanup existing dummy if exists
    #
    # @return [undefined]
    def clean_up
      dummy_path.rmtree if dummy_path.directory?
    end

    # Generate new skeleton rails app to be configured into dummy
    #
    # @return [undefined]
    def generate
      # AppGenerator generator changes work directory globally.
      #
      # Dir.chdir with a block will warn so save and restore the
      # working directory the old way.
      original = Pathname.pwd

      invoke(
        Rails::Generators::AppGenerator,
        [dummy_path.to_path],
        database:    'postgresql',
        skip_bundle: true
      )

      Dir.chdir(original)
    end

    # Cleanup uneeded files from dummy
    #
    # @return [undefined]
    def clean
      REMOVE_DUMMY_FILES.each(&method(:remove_file))
    end

    # Setup files
    #
    # @return [undefined]
    def setup_files
      COPY_FILES.each do |path|
        copy_file(path, dummy_path.join(path))
      end
    end

    # Configure dummy
    #
    # @return [undefined]
    def configure
      template('config/database.yml.erb', 'config/database.yml')
    end

    # Install migrations
    #
    # @return [undefined]
    def install_migrations
      silence_stream($stdout) do
        rake('railties:install:migrations')
      end
    end

    # Add routes
    #
    # @return [undefined]
    def add_routes
      insert_into_file(
        'config/routes.rb',
        "\nmount Spree::Core::Engine, at: '/'",
        after: 'Rails.application.routes.draw do'
      )
    end

  private

    # The dummy application path
    #
    # @return [Pathname]
    def dummy_path
      Pathname.new(options.fetch('dummy_path'))
    end

  end # DummyGenerator
end # Spree
