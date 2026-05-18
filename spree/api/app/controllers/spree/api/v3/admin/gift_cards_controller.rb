module Spree
  module Api
    module V3
      module Admin
        # Admin CRUD for `Spree::GiftCard`. Scoped to the current store via
        # the model's `SingleStoreResource` include — the base controller's
        # `scope` already applies `model_class.for_store(current_store)`.
        #
        # `store` and `created_by` are auto-stamped by `build_resource` in
        # `Spree::Api::V3::ResourceController`, so create requests only need
        # to include user-facing attributes (amount, currency, expires_at,
        # optional code, optional user_id).
        class GiftCardsController < ResourceController
          scoped_resource :gift_cards

          protected

          def model_class
            Spree::GiftCard
          end

          def serializer_class
            Spree.api.admin_gift_card_serializer
          end

          def permitted_params
            params.permit(:code, :amount, :expires_at, :user_id, :currency)
          end
        end
      end
    end
  end
end
