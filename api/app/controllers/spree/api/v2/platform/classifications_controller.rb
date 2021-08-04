module Spree
  module Api
    module V2
      module Platform
        class ClassificationsController < ResourceController
          before_action -> { doorkeeper_authorize! :write, :admin }, only: WRITE_ACTIONS << :reposition

          def reposition
            spree_authorize! :update, resource if spree_current_user.present?

            result = classification_reposition_service.call(
              classification: resource,
              position: permitted_resource_params[:position]
            )

            if result.success?
              render_serialized_payload { serialize_resource(result.value) }
            else
              render_error_payload(result.error)
            end
          end

          private

          def model_class
            Spree::Classification
          end

          def scope_includes
            [
              taxon: [],
              product: [:variants_including_master, :variant_images, :master, variants: [:prices]]
            ]
          end

          def classification_reposition_service
            Spree::Dependencies.classification_reposition_service.constantize
          end
        end
      end
    end
  end
end
