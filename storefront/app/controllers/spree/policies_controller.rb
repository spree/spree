module Spree
  class PoliciesController < StoreController
    def show
      if params[:id].in?(supported_policies)
        @policy = case params[:id]
                  when 'privacy_policy'
                    current_store.customer_privacy_policy
                  when 'terms_of_service'
                    current_store.customer_terms_of_service
                  when 'returns_policy'
                    current_store.customer_returns_policy
                  when 'shipping_policy'
                    current_store.customer_shipping_policy
                  end
      else
        raise ActiveRecord::RecordNotFound
      end
    end

    private

    def supported_policies
      %w[privacy_policy terms_of_service returns_policy shipping_policy]
    end
  end
end
