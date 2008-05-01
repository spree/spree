#!/usr/bin/env ruby

# Define a task library for running RSpec contexts.

require 'rake'
require 'rake/tasklib'

module Spec
  module Rake

    # A Rake task that runs a set of specs.
    #
    # Example:
    #  
    #   Spec::Rake::SpecTask.new do |t|
    #     t.warning = true
    #     t.rcov = true
    #   end
    #
    # This will create a task that can be run with:
    #
    #   rake spec
    #
    # If rake is invoked with a "SPEC=filename" command line option,
    # then the list of spec files will be overridden to include only the
    # filename specified on the command line.  This provides an easy way
    # to run just one spec.
    #
    # If rake is invoked with a "SPEC_OPTS=options" command line option,
    # then the given options will override the value of the +spec_opts+
    # attribute.
    #
    # If rake is invoked with a "RCOV_OPTS=options" command line option,
    # then the given options will override the value of the +rcov_opts+
    # attribute.
    #
    # Examples:
    #
    #   rake spec                                      # run specs normally
    #   rake spec SPEC=just_one_file.rb                # run just one spec file.
    #   rake spec SPEC_OPTS="--diff"                   # enable diffing
    #   rake spec RCOV_OPTS="--aggregate myfile.txt"   # see rcov --help for details
    #
    # Each attribute of this task may be a proc. This allows for lazy evaluation,
    # which is sometimes handy if you want to defer the evaluation of an attribute value
    # until the task is run (as opposed to when it is defined).
    #
    # This task can also be used to run existing Test::Unit tests and get RSpec
    # output, for example like this:
    #
    #   require 'rubygems'
    #   require 'spec/rake/spectask'
    #   Spec::Rake::SpecTask.new do |t|
    #     t.ruby_opts = ['-rtest/unit']
    #     t.spec_files = FileList['test/**/*_test.rb']
    #   end
    #
    class SpecTask < ::Rake::TaskLib
      class << self
        def attr_accessor(*names)
          super(*names)
          names.each do |name|
            module_eval "def #{name}() evaluate(@#{name}) end" # Allows use of procs
          end
        end
      end

      # Name of spec task. (default is :spec)
      attr_accessor :name

      # Array of directories to be added to $LOAD_PATH before running the
      # specs. Defaults to ['<the absolute path to RSpec's lib directory>']
      attr_accessor :libs

      # If true, requests that the specs be run with the warning flag set.
      # E.g. warning=true implies "ruby -w" used to run the specs. Defaults to false.
      attr_accessor :warning

      # Glob pattern to match spec files. (default is 'spec/**/*_spec.rb')
      # Setting the SPEC environment variable overrides this.
      attr_accessor :pattern

      # Array of commandline options to pass to RSpec. Defaults to [].
      # Setting the SPEC_OPTS environment variable overrides this.
      attr_accessor :spec_opts

      # Whether or not to use RCov (default is false)
      # See http://eigenclass.org/hiki.rb?rcov
      attr_accessor :rcov
      
      # Array of commandline options to pass to RCov. Defaults to ['--exclude', 'lib\/spec,bin\/spec'].
      # Ignored if rcov=false
      # Setting the RCOV_OPTS environment variable overrides this.
      attr_accessor :rcov_opts

      # Directory where the RCov report is written. Defaults to "coverage"
      # Ignored if rcov=false
      attr_accessor :rcov_dir

      # Array of commandline options to pass to ruby. Defaults to [].
      attr_accessor :ruby_opts

      # Whether or not to fail Rake when an error occurs (typically when specs fail).
      # Defaults to true.
      attr_accessor :fail_on_error

      # A message to print to stderr when there are failures.
      attr_accessor :failure_message

      # Where RSpec's output is written. Defaults to STDOUT.
      # DEPRECATED. Use --format FORMAT:WHERE in spec_opts.
      attr_accessor :out

      # Explicitly define the list of spec files to be included in a
      # spec.  +spec_files+ is expected to be an array of file names (a
      # FileList is acceptable).  If both +pattern+ and +spec_files+ are
      # used, then the list of spec files is the union of the two.
      # Setting the SPEC environment variable overrides this.
      attr_accessor :spec_files
      
      # Use verbose output. If this is set to true, the task will print
      # the executed spec command to stdout. Defaults to false.
      attr_accessor :verbose

      # Defines a new task, using the name +name+.
      def initialize(name=:spec)
        @name = name
        @libs = [File.expand_path(File.dirname(__FILE__) + '/../../../lib')]
        @pattern = nil
        @spec_files = nil
        @spec_opts = []
        @warning = false
        @ruby_opts = []
        @fail_on_error = true
        @rcov = false
        @rcov_opts = ['--exclude', 'lib\/spec,bin\/spec,config\/boot.rb']
        @rcov_dir = "coverage"

        yield self if block_given?
        @pattern = 'spec/**/*_spec.rb' if pattern.nil? && spec_files.nil?
        define
      end

      def define # :nodoc:
        spec_script = File.expand_path(File.dirname(__FILE__) + '/../../../bin/spec')

        lib_path = libs.join(File::PATH_SEPARATOR)
        actual_name = Hash === name ? name.keys.first : name
        unless ::Rake.application.last_comment
          desc "Run specs" + (rcov ? " using RCov" : "")
        end
        task name do
          RakeFileUtils.verbose(verbose) do
            unless spec_file_list.empty?
              # ruby [ruby_opts] -Ilib -S rcov [rcov_opts] bin/spec -- examples [spec_opts]
              # or
              # ruby [ruby_opts] -Ilib bin/spec examples [spec_opts]
              cmd = "ruby "

              rb_opts = ruby_opts.clone
              rb_opts << "-I\"#{lib_path}\""
              rb_opts << "-S rcov" if rcov
              rb_opts << "-w" if warning
              cmd << rb_opts.join(" ")
              cmd << " "
              cmd << rcov_option_list
              cmd << %[ -o "#{rcov_dir}" ] if rcov
              cmd << %Q|"#{spec_script}"|
              cmd << " "
              cmd << "-- " if rcov
              cmd << spec_file_list.collect { |fn| %["#{fn}"] }.join(' ')
              cmd << " "
              cmd << spec_option_list
              if out
                cmd << " "
                cmd << %Q| > "#{out}"|
                STDERR.puts "The Spec::Rake::SpecTask#out attribute is DEPRECATED and will be removed in a future version. Use --format FORMAT:WHERE instead."
              end
              if verbose
                puts cmd
              end
              unless system(cmd)
                STDERR.puts failure_message if failure_message
                raise("Command #{cmd} failed") if fail_on_error
              end
            end
          end
        end

        if rcov
          desc "Remove rcov products for #{actual_name}"
          task paste("clobber_", actual_name) do
            rm_r rcov_dir rescue nil
          end

          clobber_task = paste("clobber_", actual_name)
          task :clobber => [clobber_task]

          task actual_name => clobber_task
        end
        self
      end

      def rcov_option_list # :nodoc:
        return "" unless rcov
        ENV['RCOV_OPTS'] || rcov_opts.join(" ") || ""
      end

      def spec_option_list # :nodoc:
        STDERR.puts "RSPECOPTS is DEPRECATED and will be removed in a future version. Use SPEC_OPTS instead." if ENV['RSPECOPTS']
        ENV['SPEC_OPTS'] || ENV['RSPECOPTS'] || spec_opts.join(" ") || ""
      end
      
      def evaluate(o) # :nodoc:
        case o
          when Proc then o.call
          else o
        end
      end

      def spec_file_list # :nodoc:
        if ENV['SPEC']
          FileList[ ENV['SPEC'] ]
        else
          result = []
          result += spec_files.to_a if spec_files
          result += FileList[ pattern ].to_a if pattern
          FileList[result]
        end
      end

    end
  end
end

