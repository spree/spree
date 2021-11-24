module Spree
  module Api
    module V2
      module Storefront
        module MetadataControllerConcern
          protected

          def ensure_valid_metadata
            if params[:public_metadata].present? && !params[:public_metadata].is_a?(ActionController::Parameters) ||
                params[:private_metadata].present? && !params[:private_metadata].is_a?(ActionController::Parameters)
              render_error_payload(I18n.t(:invalid_params, scope: 'spree.api.v2.metadata'))
            end
          end
        end
      end
    end
  end
end
