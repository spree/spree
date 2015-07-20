module Spree
  module Api
    module Responders
      module RablTemplate
        def to_format
          if template
            render template, :status => options[:status] || 200
          else
            super
          end
        rescue ActionView::MissingTemplate => e
          api_behavior
        end

        def template
          options[:default_template]
        end

        def api_behavior
          if controller.params[:action] == "destroy"
            # Render a blank template
            super
          else
            # Do nothing and fallback to the default template
          end
        end
      end
    end
  end
end
