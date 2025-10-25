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

  ALL = %w[emails api core sample admin storefront].freeze
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
      setup_test_app
      run_tests
    end
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
    else
      raise "Unknown mode: #{mode.inspect}"
    end
  end

  private

  # Check if current bundle is already usable
  #
  # @return [Boolean]
  def bundle_check
    system("bundle check --path=#{VENDOR_BUNDLE}")
  end

  # Install the current bundle
  #
  # @return [Boolean]
  #   the success of the installation
  def bundle_install
    system("bundle install --path=#{VENDOR_BUNDLE} --jobs=#{BUNDLER_JOBS} --retry=#{BUNDLER_RETRIES}")
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

    system("bundle exec --gemfile=#{gemfile_path} rake test_app ") || raise('Failed to setup the test app')
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
