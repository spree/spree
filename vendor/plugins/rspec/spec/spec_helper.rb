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

module Spec
  module Matchers
    def fail
      raise_error(Spec::Expectations::ExpectationNotMetError)
    end

    def fail_with(message)
      raise_error(Spec::Expectations::ExpectationNotMetError, message)
    end

    class Pass
      def matches?(proc, &block)
        begin
          proc.call
          true
        rescue Exception => @error
          false
        end
      end

      def failure_message
        @error.message + "\n" + @error.backtrace.join("\n")
      end
    end

    def pass
      Pass.new
    end
    
    class CorrectlyOrderedMockExpectation
      def initialize(&event)
        @event = event
      end
      
      def expect(&expectations)
        expectations.call
        @event.call
      end
    end
    
    def during(&block)
      CorrectlyOrderedMockExpectation.new(&block) 
    end
  end
end

class NonStandardError < Exception; end

module Custom
  class ExampleGroupRunner
    attr_reader :options, :arg
    def initialize(options, arg)
      @options, @arg = options, arg
    end

    def load_files(files)
    end

    def run
    end
  end  
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

describe "sandboxed rspec_options", :shared => true do
  attr_reader :options

  before(:all) do
    @original_rspec_options = $rspec_options
  end

  before(:each) do
    @options = ::Spec::Runner::Options.new(StringIO.new, StringIO.new)
    $rspec_options = options
  end

  after do
    $rspec_options = @original_rspec_options
  end
end