module Spree
  module Api
    module V3
      module Store
        module Customer
          class GiftCardsController < ResourceController
            prepend_before_action :require_authentication!

            protected

            def set_parent
              @parent = current_user
            end

            def parent_association
              :gift_cards
            end

            def model_class
              Spree::GiftCard
            end

            def serializer_class
              Spree.api.gift_card_serializer
            end

            # Override scope to filter by current store and order by created_at desc
            def scope
              super.where(store: current_store).order(created_at: :desc)
            end
          end
        end
      end
    end
  end
end
