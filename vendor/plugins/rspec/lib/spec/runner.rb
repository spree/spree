require 'spec/runner/configuration'
require 'spec/runner/options'
require 'spec/runner/option_parser'
require 'spec/runner/example_group_runner'
require 'spec/runner/command_line'
require 'spec/runner/drb_command_line'
require 'spec/runner/backtrace_tweaker'
require 'spec/runner/reporter'
require 'spec/runner/spec_parser'
require 'spec/runner/class_and_arguments_parser'

module Spec
  module Runner
    
    class ExampleGroupCreationListener
      def register_example_group(klass)
        Spec::Runner.options.add_example_group klass
        Spec::Runner.register_at_exit_hook
      end
    end
    
    Spec::Example::ExampleGroupMethods.example_group_creation_listeners << ExampleGroupCreationListener.new
    
    class << self
      def configuration # :nodoc:
        @configuration ||= Spec::Runner::Configuration.new
      end

      # Use this to configure various configurable aspects of
      # RSpec:
      #
      #   Spec::Runner.configure do |configuration|
      #     # Configure RSpec here
      #   end
      #
      # The yielded <tt>configuration</tt> object is a
      # Spec::Runner::Configuration instance. See its RDoc
      # for details about what you can do with it.
      #
      def configure
        yield configuration
      end
    
      def register_at_exit_hook # :nodoc:
        unless @already_registered_at_exit_hook
          at_exit do
            unless $! || run? || Spec::Example::ExampleGroupFactory.registered_or_ancestor_of_registered?(options.example_groups)
              success = run
              exit success if exit?
            end
          end
          @already_registered_at_exit_hook = true
        end
      end

      def options # :nodoc:
        @options ||= begin
          parser = ::Spec::Runner::OptionParser.new($stderr, $stdout)
          parser.order!(ARGV)
          parser.options
        end
      end
    
      def use options
        @options = options
      end

      def test_unit_defined?
        Object.const_defined?(:Test) && Test.const_defined?(:Unit) && Test::Unit.respond_to?(:run?)
      end

      def run?
        Runner.options.examples_run?
      end

      def run
        return true if run?
        options.run_examples
      end

      def exit?
        !test_unit_defined? || Test::Unit.run?
      end
    end
  end
end

require 'spec/interop/test' if Spec::Runner::test_unit_defined?
