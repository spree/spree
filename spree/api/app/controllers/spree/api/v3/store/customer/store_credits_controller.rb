module Spree
  module Api
    module V3
      module Store
        module Customer
          class StoreCreditsController < ResourceController
            prepend_before_action :require_authentication!

            protected

            def set_parent
              @parent = current_user
            end

            def parent_association
              :store_credits
            end

            def scope
              super.for_store(current_store).where(currency: current_currency)
            end

            def model_class
              Spree::StoreCredit
            end

            def serializer_class
              Spree.api.store_credit_serializer
            end

            # Authorization is handled by set_parent scoping to current_user
            def authorize_resource!(*)
            end
          end
        end
      end
    end
  end
end
