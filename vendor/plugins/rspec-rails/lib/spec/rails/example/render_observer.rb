require 'spec/mocks/framework'

module Spec
  module Rails
    module Example
      # Extends the #should_receive, #should_not_receive and #stub! methods in rspec's
      # mocking framework to handle #render calls to controller in controller examples
      # and template and view examples
      module RenderObserver

        # DEPRECATED
        #
        # Use should_receive(:render).with(opts) instead
        def expect_render(opts={})
          warn_deprecation("expect_render", "should_receive")
          register_verify_after_each
          render_proxy.should_receive(:render, :expected_from => caller(1)[0]).with(opts)
        end

        # DEPRECATED
        #
        # Use stub!(:render).with(opts) instead
        def stub_render(opts={})
          warn_deprecation("stub_render", "stub!")
          register_verify_after_each
          render_proxy.stub!(:render, :expected_from => caller(1)[0]).with(opts)
        end
        
        def warn_deprecation(deprecated_method, new_method)
          Kernel.warn <<-WARNING
#{deprecated_method} is deprecated and will be removed from a future version of rspec-rails.

Please just use object.#{new_method} instead.
WARNING
        end
  
        def verify_rendered # :nodoc:
          render_proxy.rspec_verify
        end
  
        def unregister_verify_after_each #:nodoc:
          proc = verify_rendered_proc
          Spec::Example::ExampleGroup.remove_after(:each, &proc)
        end

        def should_receive(*args)
          if args[0] == :render
            register_verify_after_each
            render_proxy.should_receive(:render, :expected_from => caller(1)[0])
          else
            super
          end
        end
        
        def should_not_receive(*args)
          if args[0] == :render
            register_verify_after_each
            render_proxy.should_not_receive(:render)
          else
            super
          end
        end
        
        def stub!(*args)
          if args[0] == :render
            register_verify_after_each
            render_proxy.stub!(:render, :expected_from => caller(1)[0])
          else
            super
          end
        end

        def verify_rendered_proc #:nodoc:
          template = self
          @verify_rendered_proc ||= Proc.new do
            template.verify_rendered
            template.unregister_verify_after_each
          end
        end

        def register_verify_after_each #:nodoc:
          proc = verify_rendered_proc
          Spec::Example::ExampleGroup.after(:each, &proc)
        end
  
        def render_proxy #:nodoc:
          @render_proxy ||= Spec::Mocks::Mock.new("render_proxy")
        end
  
      end
    end
  end
end
