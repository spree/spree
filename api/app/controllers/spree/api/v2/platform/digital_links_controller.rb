module Spree
  module Api
    module V2
      module Platform
        class DigitalLinksController < ResourceController
          def reset
            spree_authorize! :update, resource if spree_current_user.present?
            resource.reset!

            if resource.save
              render_serialized_payload { serialize_resource(resource) }
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
