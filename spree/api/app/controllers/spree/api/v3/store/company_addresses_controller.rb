module Spree
  module Api
    module V3
      module Store
        # An address-book entry addressed directly. Reached through the
        # caller's standing — an entry of a node they may not act for is a
        # 404.
        class CompanyAddressesController < ResourceController
          prepend_before_action :require_authentication!

          # PATCH /api/v3/store/company_addresses/:id
          def update
            if @resource.update(permitted_params)
              render json: serialize_resource(@resource.reload)
            else
              render_validation_error(@resource.errors)
            end
          end

          # DELETE /api/v3/store/company_addresses/:id
          def destroy
            @resource.destroy!
            head :no_content
          rescue ActiveRecord::RecordNotDestroyed => e
            render_validation_error(e.record.errors.presence || e.message)
          end

          protected

          def model_class
            Spree::CompanyAddress
          end

          def serializer_class
            Spree.api.company_address_serializer
          end

          def scope
            Spree::CompanyAddress.where(
              company_id: storefront_access_policy.scope(current_store.companies).select(:id)
            )
          end

          def permitted_params
            params.permit(:label, :default_billing, :default_shipping,
                          address: Companies::AddressesController::ADDRESS_KEYS)
          end
        end
      end
    end
  end
end
