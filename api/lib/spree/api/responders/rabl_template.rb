module Spree
  module Api
    module Responders
      module RablTemplate
        def to_format
          if template
            render template.to_sym, :status => options[:status] || 200
          else
            super
          end

        rescue ActionView::MissingTemplate => e
          api_behavior(e)
        end

        def template
          request.headers['X-Spree-Template'] || controller.params[:template] || options[:default_template]
        end
      end
    end
  end
end
