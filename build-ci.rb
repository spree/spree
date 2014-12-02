#!/usr/bin/env ruby

require 'pathname'

class Project
  attr_reader :name

  NODE_TOTAL = Integer(ENV.fetch('CIRCLE_NODE_TOTAL', 1))
  NODE_INDEX = Integer(ENV.fetch('CIRCLE_NODE_INDEX', 0))

  ROOT          = Pathname.pwd.freeze
  VENDOR_BUNDLE = ROOT.join('vendor', 'bundle').freeze

  BUNDLER_JOBS    = 4
  BUNDLER_RETRIES = 3

  DEFAULT_MODE = 'test'.freeze

  def initialize(name)
    @name = name
  end

  ALL = %w[api backend core frontend sample].map(&method(:new)).freeze

  # Install subproject
  #
  # @raise [RuntimeError]
  #   in case of failure
  #
  # @return [self]
  #   otherwise
  def install
    chdir do
      bundle_check or bundle_install or fail 'Cannot finish gem installation'
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

private

  # Check if current bundle is already usable
  #
  # @return [Boolean]
  def bundle_check
    system(%W[bundle check --path=#{VENDOR_BUNDLE}])
  end

  # Install the current bundle
  #
  # @return [Boolean]
  #   the success of the installation
  def bundle_install
    system(%W[
      bundle
      install
      --path=#{VENDOR_BUNDLE}
      --jobs=#{BUNDLER_JOBS}
      --retry=#{BUNDLER_RETRIES}
    ])
  end

  # Setup the test app
  #
  # @return [undefined]
  def setup_test_app
    system(%w[bundle exec rake test_app]) or fail 'Failed to setup the test app'
  end

  # Run tests for subproject
  #
  # @return [Boolean]
  #   the success of the tests
  def run_tests
    system(%w[bundle exec rspec spec --order random])
  end

  # Execute system command via execve
  #
  # No shell interpolation gets done this way. No escapes needed.
  #
  # @return [Boolean]
  #   the success of the system command
  def system(arguments)
    Kernel.system(*arguments)
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
    NODE_INDEX.step(ALL.length - 1, NODE_TOTAL).map(&ALL.method(:fetch))
  end
  private_class_method :current_projects

  # Log a progress message to stderr
  #
  # @param [String] message
  #
  # @return [undefined]
  def self.log(message)
    $stderr.puts(message)
  end
  private_class_method :log

  # Process CLI arguments
  #
  # @param [Array<String>] arguments
  #
  # @return [Boolean]
  #   the success of the CLI run
  def self.run_cli(arguments)
    fail ArgumentError if arguments.length > 1
    mode = arguments.fetch(0, DEFAULT_MODE)

    case mode
    when 'install'
      install
      true
    when 'test'
      test
    else
      fail "Unknown mode: #{mode.inspect}"
    end
  end
end # Project

exit Project.run_cli(ARGV)
