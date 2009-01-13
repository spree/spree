require 'rr'

patterns = ::Spec::Runner::QuietBacktraceTweaker::IGNORE_PATTERNS
patterns.push(RR::Errors::BACKTRACE_IDENTIFIER)

module Spec
  module Adapters
    module MockFramework
      include RR::Extensions::InstanceMethods
      def setup_mocks_for_rspec
        RR::Space.instance.reset
      end
      def verify_mocks_for_rspec
        RR::Space.instance.verify_doubles
      end
      def teardown_mocks_for_rspec
        RR::Space.instance.reset
      end
    end
  end
end
