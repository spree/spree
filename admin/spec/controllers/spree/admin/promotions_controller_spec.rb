require 'spec_helper'

RSpec.describe Spree::Admin::PromotionsController, type: :controller do
  stub_authorization!

  render_views

  let(:user) { create(:admin_user) }
  let(:store) { @default_store }

  before do
    allow(controller).to receive(:current_ability).and_call_original
  end

  describe 'GET #index' do
    let!(:promotion) { create(:promotion, name: 'Test Promotion', stores: [store]) }

    it 'returns a successful response' do
      get :index
      expect(response).to be_successful
    end

    it 'assigns promotions for the current store' do
      get :index
      expect(assigns[:collection]).to include(promotion)
    end

    describe 'GET #show' do
      let!(:promotion) { create(:promotion, name: 'Test Promotion', stores: [store]) }
      let!(:promotion_action) { create(:promotion_action_create_adjustment) }
      let!(:promotion_rule) { create(:promotion_rule_product, promotion: promotion) }

      it 'returns a successful response' do
        get :show, params: { id: promotion.to_param }
        expect(response).to be_successful
      end

      it 'assigns the promotion' do
        get :show, params: { id: promotion.to_param }
        expect(assigns[:promotion]).to eq(promotion)
      end
    end
  end

  describe 'GET #new' do
    it 'returns a successful response' do
      get :new
      expect(response).to be_successful
    end

    it 'loads form data' do
      get :new
      expect(assigns[:promotion_rules]).not_to be_empty
      expect(assigns[:rule_types]).not_to be_empty
    end
  end

  describe 'POST #create' do
    let(:promotion_params) do
      {
        name: 'New Promotion',
        description: 'Promotion description',
        code: 'PROMO123',
        store_ids: [store.id]
      }
    end

    it 'creates a new promotion' do
      expect {
        post :create, params: { promotion: promotion_params }
      }.to change(Spree::Promotion, :count).by(1)
    end

    it 'redirects to the edit page' do
      post :create, params: { promotion: promotion_params }
      expect(response).to redirect_to(spree.admin_promotion_path(assigns[:promotion]))
    end

    context 'multi code promotion' do
      let(:promotion_params) do
        {
          name: 'New Promotion',
          kind: 'coupon_code',
          number_of_codes: 10,
          multi_codes: true,
          code_prefix: 'PRM'
        }
      end

      it 'creates a new promotion' do
        expect {
          post :create, params: { promotion: promotion_params }
        }.to change(Spree::Promotion, :count).by(1)
        promotion = Spree::Promotion.last
        expect(promotion.name).to eq('New Promotion')
        expect(promotion.kind).to eq('coupon_code')
        expect(promotion.code_prefix).to eq('PRM')
        expect(promotion.multi_codes).to be_truthy
        expect(promotion.number_of_codes).to eq(10)
      end

      it 'creates the correct number of coupon codes' do
        expect {
          post :create, params: { promotion: promotion_params }
        }.to change(Spree::CouponCode, :count).by(10)
        promotion = Spree::Promotion.last
        expect(promotion.coupon_codes.count).to eq(10)
      end
    end
  end

  describe 'GET #edit' do
    let!(:promotion) { create(:promotion, stores: [store]) }

    it 'returns a successful response' do
      get :edit, params: { id: promotion.to_param }
      expect(response).to be_successful
    end

    it 'loads form data' do
      get :edit, params: { id: promotion.to_param }
      expect(assigns[:promotion_rules]).not_to be_empty
      expect(assigns[:rule_types]).not_to be_empty
    end
  end

  describe 'PATCH #update' do
    let!(:promotion) { create(:promotion, name: 'Old Name', stores: [store]) }
    let(:promotion_params) { { name: 'Updated Name' } }

    it 'updates the promotion' do
      patch :update, params: { id: promotion.to_param, promotion: promotion_params }
      expect(promotion.reload.name).to eq('Updated Name')
    end

    it 'redirects to the edit page' do
      patch :update, params: { id: promotion.to_param, promotion: promotion_params }
      expect(response).to redirect_to(spree.admin_promotion_path(promotion))
    end
  end

  describe 'POST #clone' do
    let!(:promotion) { create(:promotion, name: 'Test Promotion', stores: [store]) }

    context 'when cloning succeeds' do
      it 'creates a duplicate promotion' do
        expect {
          post :clone, params: { id: promotion.to_param }
        }.to change(Spree::Promotion, :count).by(1)
      end

      it 'redirects to the new promotion' do
        post :clone, params: { id: promotion.to_param }
        expect(response).to redirect_to(spree.admin_promotion_path(assigns[:new_promo]))
      end

      it 'sets a success flash message' do
        post :clone, params: { id: promotion.to_param }
        expect(flash[:success]).to eq(Spree.t('promotion_cloned'))
      end
    end

    context 'when cloning fails' do
      before do
        allow_any_instance_of(Spree::PromotionHandler::PromotionDuplicator).to receive(:duplicate).and_return(
          double(errors: double(empty?: false, full_messages: ['Error message']), to_sentence: 'Error message')
        )
      end

      it 'redirects to promotions index' do
        post :clone, params: { id: promotion.to_param }
        expect(response).to redirect_to(spree.admin_promotions_path)
      end

      it 'sets an error flash message' do
        post :clone, params: { id: promotion.to_param }
        expect(flash[:error]).to include('Error message')
      end
    end
  end
end
