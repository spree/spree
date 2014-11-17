class Spree::Api::StoreCreditEventsController < Spree::Api::BaseController
  def mine
    if current_api_user.persisted?
      @store_credit_events = current_api_user.store_credit_events.exposed_events.page(params[:page]).per(params[:per_page]).reverse_chronological
    else
      render "spree/api/errors/unauthorized", status: :unauthorized
    end
  end
end
