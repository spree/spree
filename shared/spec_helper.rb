require 'adamantium'
require 'concord'
require 'database_cleaner'
require 'ffaker'
require 'rspec/its'
require 'timeout'
require 'ice_nine'

# @api private
class SpecHelper
  include Adamantium::Flat, Concord.new(:rspec_config, :specdir)

  private_class_method :new

  # Infect environment with spec helper
  #
  # @param config [RSpec::Configuration]
  # @param specdir [String]
  #
  # @return [self]
  def self.infect(*arguments)
    new(*arguments)

    self
  end

private

  # Initialize object
  #
  # @return [undfined]
  def initialize(*)
    super

    base
    dummy_app
    support
    remove_global_fixture_include
    clean_db_before_suite
    setup_database_cleaning
  end

  # Initialize spec environment shared by all subprojects
  #
  # @return [undefined]
  def base
    if ENV.key?('COVERAGE')
      # Run Coverage report
      require 'simplecov'
      SimpleCov.start do
        add_group('Controllers', 'app/controllers')
        add_group('Helpers',     'app/helpers')
        add_group('Mailers',     'app/mailers')
        add_group('Models',      'app/models')
        add_group('Views',       'app/views')
        add_group('Libraries',   'lib')
      end
    end

    ENV['RAILS_ENV'] ||= 'test'
  end

  # Initialize spec environment for subprojects that require the dummy app
  #
  # @return [undefined]
  def dummy_app
    require(specdir.join('dummy/config/environment'))
    require('rspec/rails')  # Can only be loaded after rails :(
  end

  # Load spec support files
  #
  # @return [undefined]
  def support
    Pathname
      .glob(specdir.join('support/**/*.rb'))
      .sort
      .each(&method(:require))
  end

  # Clean out the database state before the tests run
  #
  # @return [undefined]
  def clean_db_before_suite
    rspec_config.before(:suite) do
      DatabaseCleaner.clean_with(:truncation)
    end
  end

  # Setup database cleaning for each example
  #
  # @return [undefined]
  def setup_database_cleaning
    rspec_config.around do |example|
      DatabaseCleaner.strategy =
        example.metadata.fetch(:js, false) ? :truncation : :transaction

      DatabaseCleaner.cleaning(&example)
    end
  end

  # Workaround rspec fixture bug that includes the
  # fixture support (with hooks and DB traffic) in *all* examples
  # where it should only include it into `use_fixtures: true` examples.
  #
  # There is no public API for removing inclusions, so we have to peak
  # deep into the internals.
  #
  # Also makes `assert` that was unintentionally transitively included
  # unavailable.
  #
  # @see https://github.com/rspec/rspec-rails/issues/1355
  #
  # @return [undefined]
  def remove_global_fixture_include
    rspec_config
      .instance_variable_get(:@include_modules)
      .instance_variable_get(:@items_and_filters)
      .delete([RSpec::Rails::FixtureSupport, {}])
  end

end # SpecHelper
