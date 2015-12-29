#!/usr/bin/env ruby

require 'pathname'

# @api private
module Devtools
  # A task to be executed
  class Task
    # Initialize object
    #
    # @return [undefined]
    def initialize(project, rake_task)
      @project, @rake_task = project, rake_task
    end

    # The proejct the task is running under
    #
    # @return [Project]
    attr_reader :project
    private :project

    # The rake task to be executed under project
    #
    # @return [String]
    attr_reader :rake_task
    private :rake_task

    # The task name for reports
    #
    # @return [String]
    def name
      "#{project.name} #{rake_task}"
    end

    # Execute the task
    #
    # @return [Boolean]
    def call
      project
        .install
        .rake_task(rake_task)
    end
  end # Task

  class Project
    ROOT            = Pathname.pwd.freeze
    BUNDLER_JOBS    = 4
    BUNDLER_RETRIES = 3
    SYSTEM_ENV      = { 'RAILS_ENV' => 'test' }.freeze

    TASK_NAMES = %w[
      metrics:coverage
      metrics:yardstick:verify
      metrics:rubocop
      metrics:flog
      metrics:flay
      metrics:reek
    ].freeze

    private_constant(*constants)

    # Initialize object
    #
    # @param name [String]
    #
    # @param [String]
    def initialize(name)
      @name = name
    end

    # The project name
    #
    # @return [String]
    attr_reader :name

    # Install the project
    #
    # This is an idempotent operation to speed up the case
    # two tasks are run in the same container.
    #
    # The project will only be installed once.
    #
    # @return [self]
    def install
      @installed ||= begin
        bundle_install
        setup_test_app
        self
      end
    end

    # The tasks available for project
    #
    # @return [Enumerable<Task|]
    def tasks
      TASK_NAMES.map { |name| Task.new(self, name) }
    end

    # Execute rake task
    #
    # @param [String] task_name
    #
    # @return [Boolean]
    def rake_task(task_name)
      system(%W[bundle exec rake #{task_name}])
    end

  private

    # Install the current bundle
    #
    # @return [Boolean]
    #   the success of the installation
    def bundle_install
      system(%W[
        bundle
        install
        --jobs #{BUNDLER_JOBS}
        --retry #{BUNDLER_RETRIES}
      ]) or fail 'Cannot finish gem installation'
    end

    # Execute system command via execve in project directory
    #
    # No shell interpolation gets done this way. No escapes needed.
    #
    # @return [Boolean]
    #   the success of the system command
    def system(arguments)
      chdir { Kernel.system(SYSTEM_ENV, *arguments) }
    end

    # Setup the test app
    #
    # @return [Boolean]
    #   the success of the test app setup
    def setup_test_app
      rake_task('test_app') or fail 'Failed to setup the test app'
    end

    # Change to subproject directory and execute block
    #
    # @return [undefined]
    def chdir(&block)
      Dir.chdir(ROOT.join(name), &block)
    end
  end

  class Env
    PROJECT_NAMES = %w[api backend core frontend].freeze

    private_constant(*constants)

    # Initialize object
    #
    # @return [undefined]
    def initialize
      @node_total = Integer(ENV.fetch('BUILDKITE_PARALLEL_JOB_COUNT', '1'))
      @node_index = Integer(ENV.fetch('BUILDKITE_PARALLEL_JOB', '0'))
      all_tasks   = PROJECT_NAMES.map(&Project.method(:new)).flat_map(&:tasks)

      @tasks = node_index
        .step(all_tasks.length - 1, node_total)
        .map(&all_tasks.method(:fetch))
    end

    # The total amount of nodes available
    #
    # @return [Fixnum]
    attr_reader :node_total

    # The index of the current node
    #
    # @return [Fixnum]
    attr_reader :node_index

    # The tasks detected for current node
    #
    # @return [Enumerable<Task>]
    attr_reader :tasks
  end # Env

  # CLI handler
  class CLI
    private_class_method :new

    # Process commandline arguments
    #
    # @param arguments [Array<String>]
    #
    # @return [Boolean]
    def self.call(arguments)
      new(Env.new, arguments).call
    end

    # Initialize object
    #
    # @param env [Env]
    # @param arguments [Array<String>]
    #
    # @return [undefined]
    def initialize(env, arguments)
      @env, @arguments = env, arguments
    end

    # The arguments CLI was called with
    #
    # @return [Array<String>]
    attr_reader :arguments
    private :arguments

    # The environment CLI is running under
    #
    # @return [Env]
    attr_reader :env
    private :env

    # Process arguments
    #
    # @return [Boolean]
    #   the success of the CLI run
    def call
      # Keep compatibility during transition
      #
      # The current CI configuration needs to work for both master and while
      # the change is in a branch.
      if arguments.any?
        log("#{$0} does not take arguments anymore. 'install' and 'test' are merged, 'install' is a noop")
        return true if arguments.eql?(%w[install])
      end

      tasks  = env.tasks
      suffix = "#{tasks.length} tasks(s) on node #{env.node_index.succ} / #{env.node_total}"

      log("Running #{suffix}")
      tasks.each do |task|
        log("- #{task.name}")
      end

      builds = tasks.map do |task|
        log("Building: #{task.name}")
        task.call.tap do
          log("Finished: #{task.name}")
        end
      end
      log("Finished running #{suffix}")

      tasks.zip(builds).each do |task, build|
        log("- #{task.name} #{build ? 'SUCCESS' : 'FAILURE'}")
      end

      builds.all?
    end

  private

    # Utility to log a progress message to stderr
    #
    # @param [String] message
    #
    # @return [undefined]
    def log(message)
      $stderr.puts(message)
    end
  end # Project
end # Devtools

exit Devtools::CLI.call(ARGV)
