module Spree
  class PoliciesController < StoreController
    # GET /policies/<policy_slug>
    def show
      @policy = current_store.policies.friendly.find(params[:id])
    end
  end
end
