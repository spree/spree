require 'adamantium'
require 'concord'
require 'database_cleaner'
require 'ffaker'
require 'rspec/its'
require 'timeout'

# @api private
class SpecHelper
  include Adamantium, Concord.new(:specdir)

  # Infect environment with spec helper
  #
  # @param specdir [String]
  #
  # @return [SpecHelper]
  def self.infect(specdir)
    new(Pathname.new(specdir))
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
    RSpec.configure do |config|
      config
        .instance_variable_get(:@include_modules)
        .instance_variable_get(:@items_and_filters)
        .delete([RSpec::Rails::FixtureSupport, {}])
    end
  end

end # SpecHelper
