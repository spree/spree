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

            request_params :claim do
              object :items, array: true, required: :create, only: :create,
                             description: 'Affected items, and how each should be made right.' do
                id :line_item_id, required: true
                integer :quantity, required: true
                string :description
                boolean :send_replacement
                id :replacement_variant_id, description: 'Defaults to the variant that was bought.'
                decimal :refund_amount
              end
              id :reason_id, description: "One of the store's claim reasons."
              string :memo
              object :metadata, only: :update
            end

            request_params 'ClaimResolveParams', action: :resolve do
              string :resolution, required: true, enum: Spree::Claim::RESOLUTIONS, description: 'Money back, a replacement shipment, or both.'
              string :refund_method, enum: Spree::RefundMethods::METHODS, description: 'Defaults to `store_credit`.'
              decimal :amount, description: 'Defaults to the claim total.'
              id :replacement_line_item_ids, array: true,
                                             description: 'Which claim lines to send a replacement for. Omit to keep what the claim was opened with.'
            end

            request_params 'ClaimDenyParams', action: :deny do
              string :reason, description: 'Recorded on the claim for the customer.'
            end

            request_params 'ClaimCancelParams', action: :cancel do
              string :reason, description: 'A note on why the claim was canceled.'
            end

            before_action :set_resource, only: [:show, :update, :approve, :resolve, :deny, :cancel]

            # PATCH /api/v3/admin/orders/:order_id/claims/:id
            #
            # Editable fields only — status moves through the member actions.
            def update
              if @resource.update(update_attributes)
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
              params.permit(*permitted_attributes)
            end

            private

            # The reason is resolved through the store rather than assigned
            # raw, so another store's reads as missing.
            def update_attributes
              attributes = permitted_params.to_h.except('reason_id')

              if params.key?(:reason_id)
                attributes['reason'] =
                  (current_store.claim_reasons.find_by_prefix_id!(params[:reason_id]) if params[:reason_id].present?)
              end

              attributes
            end

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
