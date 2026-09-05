module Spree
  module Api
    module V3
      module Admin
        module Orders
          # Claims on a completed order.
          class ClaimsController < BaseController
            include Spree::Api::V3::Orders::ClaimActions

            # Claims are a subject of the `orders` catalog resource, so
            # `read_orders`/`write_orders` gate these endpoints. `:claims`
            # would name a key no catalog knows.
            scoped_resource :orders

            before_action :set_resource, only: [:show, :update, :approve, :resolve, :deny, :cancel]

            # PATCH /api/v3/admin/orders/:order_id/claims/:id
            #
            # Editable fields only — status moves through the member actions.
            def update
              if @resource.update(permitted_params)
                render json: serialize_resource(@resource.reload)
              else
                render_validation_error(@resource.errors)
              end
            end

            protected

            def serializer_class
              Spree.api.admin_claim_serializer
            end

            def collection_includes
              [:reason, { claim_line_items: [:variant, :replacement_variant] }]
            end

            def permitted_params
              params.permit(:memo, :reason_id, metadata: {})
            end

            private

            # The whole store's catalogue: an operator may promise anything
            # the store sells as a replacement.
            def replacement_variant_for(variant_id)
              return nil if variant_id.blank?

              current_store.variants.find_by_prefix_id!(variant_id)
            end
          end
        end
      end
    end
  end
end
