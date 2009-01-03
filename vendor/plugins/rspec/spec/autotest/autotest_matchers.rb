module Spec
  module Matchers
    class AutotestMappingMatcher
      def initialize(specs)
        @specs = specs
      end
  
      def to(file)
        @file = file
        self
      end
  
      def matches?(autotest)
        @autotest = prepare autotest
        @actual = autotest.test_files_for(@file)
        @actual == @specs
      end
  
      def failure_message
        "expected #{@autotest.class} to map #{@specs.inspect} to #{@file.inspect}\ngot #{@actual.inspect}"
      end
  
      private
      def prepare autotest
        stub_found_files autotest
        stub_find_order autotest
        autotest
      end
  
      def stub_found_files autotest
        found_files = @specs.inject({}){|h,f| h[f] = Time.at(0)}
        autotest.stub!(:find_files).and_return(found_files)
      end

      def stub_find_order autotest
        find_order = @specs.dup << @file
        autotest.instance_eval { @find_order = find_order }
      end

    end
    
    def map_specs(specs)
      AutotestMappingMatcher.new(specs)
    end
    
  end
end