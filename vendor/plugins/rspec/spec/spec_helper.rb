require 'stringio'

dir = File.dirname(__FILE__)
lib_path = File.expand_path("#{dir}/../lib")
$LOAD_PATH.unshift lib_path unless $LOAD_PATH.include?(lib_path)
$_spec_spec = true # Prevents Kernel.exit in various places

require 'spec'
require 'spec/mocks'
require 'spec/story'
spec_classes_path = File.expand_path("#{dir}/../spec/spec/spec_classes")
require spec_classes_path unless $LOAD_PATH.include?(spec_classes_path)
require File.dirname(__FILE__) + '/../lib/spec/expectations/differs/default'

def jruby?
  ::RUBY_PLATFORM == 'java'
end

module Spec  
  module Example
    class NonStandardError < Exception; end
  end

  module Matchers
    def fail
      raise_error(Spec::Expectations::ExpectationNotMetError)
    end

    def fail_with(message)
      raise_error(Spec::Expectations::ExpectationNotMetError, message)
    end

    def exception_from(&block)
      exception = nil
      begin
        yield
      rescue StandardError => e
        exception = e
      end
      exception
    end
    
    def run_with(options)
      ::Spec::Runner::CommandLine.run(options)
    end

    def with_ruby(version)
      yield if RUBY_PLATFORM =~ Regexp.compile("^#{version}")
    end
  end
end

def with_sandboxed_options
  attr_reader :options
  
  before(:each) do
    @original_rspec_options = ::Spec::Runner.options
    ::Spec::Runner.use(@options = ::Spec::Runner::Options.new(StringIO.new, StringIO.new))
  end

  after(:each) do
    ::Spec::Runner.use(@original_rspec_options)
  end
  
  yield
end

def with_sandboxed_config
  attr_reader :config
  
  before(:each) do
    @config = ::Spec::Runner::Configuration.new
    @original_configuration = ::Spec::Runner.configuration
    spec_configuration = @config
    ::Spec::Runner.instance_eval {@configuration = spec_configuration}
  end
  
  after(:each) do
    original_configuration = @original_configuration
    ::Spec::Runner.instance_eval {@configuration = original_configuration}
    ::Spec::Example::ExampleGroupFactory.reset
  end
  
  yield
end
