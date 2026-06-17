require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::PromotionRulesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:promotion) { create(:promotion, stores: [store]) }

  before { request.headers.merge!(headers) }

  describe 'POST #create' do
    it 'creates a rule on a promotion in the current store' do
      post :create, params: {
        promotion_id: promotion.prefixed_id,
        type: 'first_order'
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(promotion.reload.promotion_rules.map(&:type)).to include('Spree::Promotion::Rules::FirstOrder')
    end

    it "404s for a promotion that belongs to another store" do
      foreign_promotion = create(:promotion, stores: [create(:store)])

      post :create, params: {
        promotion_id: foreign_promotion.prefixed_id,
        type: 'first_order'
      }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(foreign_promotion.reload.promotion_rules).to be_empty
    end
  end

  describe 'GET #index' do
    it "404s when listing rules of another store's promotion" do
      foreign_promotion = create(:promotion, stores: [create(:store)])
      create(:promotion_rule_user, promotion: foreign_promotion)

      get :index, params: { promotion_id: foreign_promotion.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
