require 'spec/interop/test'

ActionView::Base.cache_template_extensions = false

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

        @@model_id = 1000
        # Creates a mock object instance for a +model_class+ with common
        # methods stubbed out.
        # Additional methods may be easily stubbed (via add_stubs) if +stubs+ is passed.
        def mock_model(model_class, options_and_stubs = {})
          # null = options_and_stubs.delete(:null_object)
          # stubs = options_and_stubs
          id = @@model_id
          @@model_id += 1
          options_and_stubs = {
            :id => id,
            :to_param => id.to_s,
            :new_record? => false,
            :errors => stub("errors", :count => 0)
          }.merge(options_and_stubs)
          m = mock("#{model_class.name}_#{id}", options_and_stubs)
          m.send(:__mock_proxy).instance_eval <<-CODE
            def @target.is_a?(other)
              #{model_class}.ancestors.include?(other)
            end
            def @target.kind_of?(other)
              #{model_class}.ancestors.include?(other)
            end
            def @target.instance_of?(other)
              other == #{model_class}
            end
            def @target.class
              #{model_class}
            end
          CODE
          yield m if block_given?
          m
        end

        #--
        # TODO - Shouldn't this just be an extension of stub! ??
        # - object.stub!(:method => return_value, :method2 => return_value2, :etc => etc)
        #++
        # Stubs methods on +object+ (if +object+ is a symbol or string a new mock
        # with that name will be created). +stubs+ is a Hash of <tt>method=>value</tt>
        def add_stubs(object, stubs = {}) #:nodoc:
          m = [String, Symbol].index(object.class) ? mock(object.to_s) : object
          stubs.each {|k,v| m.stub!(k).and_return(v)}
          m
        end
        Spec::Example::ExampleGroupFactory.default(self)
      end
    end
  end
end
