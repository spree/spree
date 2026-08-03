module Spree
  module Api
    module V3
      module Admin
        # Cross-order listing of claims — "what is awaiting resolution across
        # the whole store". Read-only by route: opening a claim needs an
        # order, so creation and the status transitions stay on the nested
        # Orders::ClaimsController.
        class ClaimsController < ResourceController
          # Post-sale records are order data: a key that may read orders may
          # read these, and nothing here writes.
          scoped_resource :orders

          protected

          def model_class
            Spree::Claim
          end

          def serializer_class
            Spree.api.admin_claim_serializer
          end

          def collection_includes
            [:order, :reason, { claim_line_items: :variant }]
          end
        end
      end
    end
  end
end
