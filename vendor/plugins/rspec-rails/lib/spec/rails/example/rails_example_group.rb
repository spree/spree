require 'spec/interop/test'

if ActionView::Base.respond_to?(:cache_template_extension)
  ActionView::Base.cache_template_extensions = false
end

module Spec
  module Rails

    module Example
      class RailsExampleGroup < Test::Unit::TestCase
        
        # Rails >= r8570 uses setup/teardown_fixtures explicitly
        before(:each) do
          setup_fixtures if self.respond_to?(:setup_fixtures)
        end
        after(:each) do
          teardown_fixtures if self.respond_to?(:teardown_fixtures)
        end
        
        include Spec::Rails::Matchers
        include Spec::Rails::Mocks
        
        Spec::Example::ExampleGroupFactory.default(self)
        
      end
    end
  end
end
