module Spree
  module Api
    module V2
      module Platform
        class DigitalLinksController < ResourceController
          def reset
            spree_authorize! :update, resource if spree_current_user.present?

            if resource.reset!
              render_serialized_payload { serialize_resource(resource) }
            else
              render_error_payload(resource.errors)
            end
          end

          private

          def model_class
            Spree::DigitalLink
          end
        end
      end
    end
  end
end
