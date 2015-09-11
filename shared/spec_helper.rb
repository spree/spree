require 'adamantium'
require 'concord'

class SpecHelper
  include Adamantium, Concord.new(:specdir)

  # Return new object
  #
  # @param specdir [String]
  #
  # @return [SpecHelper]
  #
  # @api private
  def self.new(specdir)
    super(Pathname.new(specdir)).base
  end

  # Initialize spec environment shared by all subprojects
  #
  # @return [self]
  #
  # @api private
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

    self
  end

  # Initialize spec environment for subprojects that require the dummy app
  #
  # @return [self]
  #
  # @api private
  def dummy_app
    begin
      require(specdir.join('dummy/config/environment'))
    rescue LoadError
      fail 'Could not load dummy application. Please ensure you have run `bundle exec rake test_app`'
    end

    require 'rspec/rails'
    require 'rspec/its'
    require 'database_cleaner'
    require 'ffaker'
    require 'timeout'

    self
  end

  # Load spec support files
  #
  # @return [self]
  #
  # @api private
  def support
    Dir.glob(File.join(specdir, 'support/**/*.rb')).sort.each(&method(:require))

    self
  end

end # SpecHelper
