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

end # SpecHelper
