module Spree
  class PoliciesController < StoreController
    def show
      if params[:id].in?(supported_policies)
        @policy = current_store.send("customer_#{params[:id]}")
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
