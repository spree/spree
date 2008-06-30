require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "lib", "spec", "mocks"))
require 'spec/mocks/framework'
require 'spec/mocks/extensions'

module Spec
  module Plugins
    module MockFramework
      include Spec::Mocks::ExampleMethods
      def setup_mocks_for_rspec
        $rspec_mocks ||= Spec::Mocks::Space.new
      end
      def verify_mocks_for_rspec
        $rspec_mocks.verify_all
      end
      def teardown_mocks_for_rspec
        $rspec_mocks.reset_all
      end
    end
  end
end
