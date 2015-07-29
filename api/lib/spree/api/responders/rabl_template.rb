module Spree
  module Api
    module Responders
      module RablTemplate
        def to_format
          if template
            render(template, status: options.fetch(:status, :ok))
          else
            super()
          end
        end

      private

        def template
          options[:default_template]
        end

      end
    end
  end
end
