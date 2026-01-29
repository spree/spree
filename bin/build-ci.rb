#!/usr/bin/env ruby

require 'pathname'

class Project
  attr_reader :name

  NODE_TOTAL = Integer(ENV.fetch('CIRCLE_NODE_TOTAL', 1))
  NODE_INDEX = Integer(ENV.fetch('CIRCLE_NODE_INDEX', 0))

  ROOT          = Pathname.pwd.freeze
  VENDOR_BUNDLE = ROOT.join('vendor', 'bundle').freeze
  ROOT_GEMFILE  = ROOT.join('Gemfile').freeze

  BUNDLER_JOBS    = 4
  BUNDLER_RETRIES = 3

  DEFAULT_MODE = 'test'.freeze

  def initialize(name)
    @name = name
  end

  ALL = %w[emails api core sample admin storefront page_builder].freeze
  CORE_GEMS = %w[api core].freeze

  # Install subproject
  #
  # @raise [RuntimeError]
  #   in case of failure
  #
  # @return [self]
  #   otherwise
  def install
    chdir do
      bundle_check || bundle_install || raise('Cannot finish gem installation')
    end
    self
  end

  # Test subproject for passing its tests
  #
  # @return [Boolean]
  #   the success of the build
  def pass?
    chdir do
      run_tests
    end
  end

  # Setup test app (without running tests)
  #
  # @return [self]
  def setup
    chdir do
      setup_test_app
    end
    self
  end

  # Setup database for the test app
  #
  # @return [self]
  def setup_db
    chdir do
      Dir.chdir('spec/dummy') do
        # Install migrations from all Spree gems
        system('bin/rails g spree:install:migrations') || true
        system('bin/rails g spree_api:install:migrations') || true
        # Create database and load schema
        system('bin/rake db:create db:schema:load') || raise('Failed to setup database')
      end
    end
    self
  end

  # Process CLI arguments
  #
  # @param [Array<String>] arguments
  #
  # @return [Boolean]
  #   the success of the CLI run
  def self.run_cli(arguments)
    raise ArgumentError if arguments.length > 1

    mode = arguments.fetch(0, DEFAULT_MODE)

    case mode
    when 'install'
      install
      true
    when 'test'
      test
    when 'setup'
      setup
      true
    when 'setup_db'
      setup_db
      true
    else
      raise "Unknown mode: #{mode.inspect}"
    end
  end

  private

  # Configure bundler path
  #
  # @return [Boolean]
  def bundle_config
    system("bundle config set --local path #{VENDOR_BUNDLE}")
  end

  # Check if current bundle is already usable
  #
  # @return [Boolean]
  def bundle_check
    bundle_config
    system("bundle check")
  end

  # Install the current bundle
  #
  # @return [Boolean]
  #   the success of the installation
  def bundle_install
    bundle_config
    system("bundle install --jobs=#{BUNDLER_JOBS} --retry=#{BUNDLER_RETRIES}")
  end

  # Setup the test app
  #
  # @return [undefined]
  def setup_test_app
    gemfile_path = if CORE_GEMS.include?(self.name)
                     ROOT_GEMFILE
                   else
                     './Gemfile'
                   end

    env_vars = []
    env_vars << "USE_PREBUILT_APP=#{ENV['USE_PREBUILT_APP']}" if ENV['USE_PREBUILT_APP']

    system("#{env_vars.join(' ')} bundle exec --gemfile=#{gemfile_path} rake test_app ") || raise('Failed to setup the test app')
  end

  # Run tests for subproject
  #
  # @return [Boolean]
  #   the success of the tests
  def run_tests
    system("circleci tests glob \"spec/**/*_spec.rb\" | circleci tests run --command=\"xargs bundle exec rspec #{rspec_arguments.join(' ')}\" --split-by=timings")
  end

  def rspec_arguments(custom_name = name)
    args = []
    args += %w[--order random --format documentation --profile 10]
    if report_dir = ENV['CIRCLE_TEST_REPORTS']
      args += %W[-r rspec_junit_formatter --format RspecJunitFormatter -o #{report_dir}/rspec/#{custom_name}.xml]
    end
    args
  end

  # Change to subproject directory and execute block
  #
  # @return [undefined]
  def chdir(&block)
    Dir.chdir(ROOT.join(name), &block)
  end

  # Install subprojects
  #
  # @return [self]
  def self.install
    current_projects.each do |project|
      log("Installing project: #{project.name}")
      project.install
    end
    self
  end
  private_class_method :install

  # Setup test app for subprojects (without running tests)
  #
  # @return [self]
  def self.setup
    current_projects.each do |project|
      log("Setting up test app for: #{project.name}")
      project.setup
    end
    self
  end
  private_class_method :setup

  # Setup database for subprojects
  #
  # @return [self]
  def self.setup_db
    current_projects.each do |project|
      log("Setting up database for: #{project.name}")
      project.setup_db
    end
    self
  end
  private_class_method :setup_db

  # Execute tests on subprojects
  #
  # @return [Boolean]
  #   the success of ALL subprojects
  def self.test
    projects = current_projects
    suffix   = "#{projects.length} projects(s) on node #{NODE_INDEX.succ} / #{NODE_TOTAL}"

    log("Running #{suffix}")
    projects.each do |project|
      log("- #{project.name}")
    end

    builds = projects.map do |project|
      log("Building: #{project.name}")
      project.pass?
    end
    log("Finished running #{suffix}")

    projects.zip(builds).each do |project, build|
      log("- #{project.name} #{build ? 'SUCCESS' : 'FAILURE'}")
    end

    builds.all?
  end
  private_class_method :test

  # Return the projects active on current node
  #
  # @return [Array<Project>]
  def self.current_projects
    ENV.fetch('PROJECTS', ALL.join(',')).split(',').map(&method(:new))
  end
  private_class_method :current_projects

  # Log a progress message to stderr
  #
  # @param [String] message
  #
  # @return [undefined]
  def self.log(message)
    warn(message)
  end
  private_class_method :log
end

exit Project.run_cli(ARGV)
