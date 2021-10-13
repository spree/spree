module Spree
  module Api
    module V2
      module Platform
        class DigitalLinksController < ResourceController
          def reset
            spree_authorize! :update, @digital_link if spree_current_user.present?

            @digital_link = scope.find(params[:id])
            @digital_link.reset!

            if @digital_link.save
              render_serialized_payload { serialize_resource(@digital_link) }
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
