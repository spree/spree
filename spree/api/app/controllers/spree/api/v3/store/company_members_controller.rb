module Spree
  module Api
    module V3
      module Store
        # Removing a member's standing, addressed directly by membership id.
        # Any member with standing over the node may do this — the accepted
        # OSS trade-off; restraint is Enterprise's policy layer.
        class CompanyMembersController < ResourceController
          prepend_before_action :require_authentication!

          # DELETE /api/v3/store/company_members/:id
          def destroy
            @resource.destroy!
            head :no_content
          rescue ActiveRecord::RecordNotDestroyed => e
            render_validation_error(e.record.errors.presence || e.message)
          end

          protected

          def model_class
            Spree::CompanyMembership
          end

          def serializer_class
            Spree.api.company_membership_serializer
          end

          def scope
            Spree::CompanyMembership.where(
              company_id: storefront_access_policy.scope(current_store.companies).select(:id)
            )
          end
        end
      end
    end
  end
end
