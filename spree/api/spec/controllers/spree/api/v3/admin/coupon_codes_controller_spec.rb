require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CouponCodesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  def multi_code_promotion(promo_store)
    create(:promotion, store: promo_store, multi_codes: true, number_of_codes: 2, code_prefix: 'SAVE')
  end

  let!(:promotion) { multi_code_promotion(store) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists coupon codes for a promotion in the current store' do
      get :index, params: { promotion_id: promotion.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_present
    end

    it "404s when reading coupon codes of another store's promotion" do
      foreign_promotion = multi_code_promotion(create(:store))

      get :index, params: { promotion_id: foreign_promotion.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
