module ActionView #:nodoc:
  class Base #:nodoc:
    include Spec::Rails::Example::RenderObserver
    cattr_accessor :base_view_path
    def render_partial(partial_path, local_assigns = nil, deprecated_local_assigns = nil) #:nodoc:
      if partial_path.is_a?(String)
        unless partial_path.include?("/")
          unless self.class.base_view_path.nil?
            partial_path = "#{self.class.base_view_path}/#{partial_path}"
          end
        end
      end
      super(partial_path, local_assigns, deprecated_local_assigns)
    end

    alias_method :orig_render, :render
    def render(options = {}, old_local_assigns = {}, &block)
      if expect_render_mock_proxy.send(:__mock_proxy).send(:find_matching_expectation, :render, options)
        expect_render_mock_proxy.render(options)
      else
        unless expect_render_mock_proxy.send(:__mock_proxy).send(:find_matching_method_stub, :render, options)
          orig_render(options, old_local_assigns, &block)
        end
      end
    end
  end
end
