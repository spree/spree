module Spec
  module Rails
    module Matchers
    
      class RenderTemplate #:nodoc:
    
        def initialize(expected, controller)
          @controller = controller
          @expected = expected
        end
      
        def matches?(response)
          @actual = response.rendered_file
          full_path(@actual) == full_path(@expected)
        end

        def failure_message
          "expected #{@expected.inspect}, got #{@actual.inspect}"
        end
        
        def negative_failure_message
          "expected not to render #{@expected.inspect}, but did"
        end
        
        def description
          "render template #{@expected.inspect}"
        end
      
        private
          def full_path(path)
            return nil if path.nil?
            path.include?('/') ? path : "#{@controller.class.to_s.underscore.gsub('_controller','')}/#{path}"
          end
        
      end

      # :call-seq:
      #   response.should render_template(path)
      #   response.should_not render_template(path)
      #
      # Passes if the specified template is rendered by the response.
      # Useful in controller specs (integration or isolation mode).
      #
      # <code>path</code> can include the controller path or not. It
      # can also include an optional extension (no extension assumes .rhtml).
      #
      # Note that partials must be spelled with the preceding underscore.
      #
      # == Examples
      #
      #   response.should render_template('list')
      #   response.should render_template('same_controller/list')
      #   response.should render_template('other_controller/list')
      #
      #   #rjs
      #   response.should render_template('list.rjs')
      #   response.should render_template('same_controller/list.rjs')
      #   response.should render_template('other_controller/list.rjs')
      #
      #   #partials
      #   response.should render_template('_a_partial')
      #   response.should render_template('same_controller/_a_partial')
      #   response.should render_template('other_controller/_a_partial')
      def render_template(path)
        RenderTemplate.new(path.to_s, @controller)
      end

    end
  end
end
