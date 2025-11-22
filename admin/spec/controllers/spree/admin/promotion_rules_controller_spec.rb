require 'spec_helper'

RSpec.describe Spree::Admin::PromotionRulesController, type: :controller do
  stub_authorization!

  render_views

  let(:user) { create(:admin_user) }
  let(:store) { @default_store }
  let(:promotion) { create(:promotion, stores: [store]) }

  describe 'GET #new' do
    it 'returns a successful response' do
      get :new, params: { promotion_id: promotion.id }
      expect(response).to be_successful
    end

    context 'when type is provided' do
      let(:rule_type) { 'Spree::Promotion::Rules::Product' }

      it 'returns a successful response' do
        get :new, params: { promotion_id: promotion.id, promotion_rule: { type: rule_type } }
        expect(response).to be_successful
      end

      it 'loads the correct rule type' do
        get :new, params: { promotion_id: promotion.id, promotion_rule: { type: rule_type } }
        expect(assigns(:promotion_rule).class).to eq(rule_type.constantize)
      end
    end
  end

  describe 'POST #create' do
    let(:rule_type) { 'Spree::Promotion::Rules::Product' }
    let(:rule_params) do
      {
        type: rule_type,
        preferred_match_policy: 'any'
      }
    end

    it 'creates a new promotion rule' do
      expect {
        post :create, params: { promotion_id: promotion.id, promotion_rule: rule_params }
      }.to change(Spree::PromotionRule, :count).by(1)
    end

    it 'redirects to the promotion page' do
      post :create, params: { promotion_id: promotion.id, promotion_rule: rule_params }
      expect(response).to redirect_to(spree.admin_promotion_path(promotion))
    end

    context 'with invalid rule type' do
      let(:rule_type) { 'InvalidRuleType' }

      it 'raises an error' do
        expect {
          post :create, params: { promotion_id: promotion.id, promotion_rule: rule_params }
        }.to raise_error('Unknown promotion rule type')
      end
    end

    context 'with preferences' do
      let(:rule_params) do
        {
          type: 'Spree::Promotion::Rules::Country',
          preferred_country_iso: 'US'
        }
      end

      it 'creates a new promotion rule' do
        expect {
          post :create, params: { promotion_id: promotion.id, promotion_rule: rule_params }
        }.to change(Spree::PromotionRule, :count).by(1)
      end

      it 'sets the preferences' do
        post :create, params: { promotion_id: promotion.id, promotion_rule: rule_params }
        expect(assigns(:promotion_rule).preferred_country_iso).to eq('US')
      end
    end
  end

  describe 'GET #edit' do
    let!(:promotion_rule) { create(:promotion_rule_user, promotion: promotion) }

    it 'returns a successful response' do
      get :edit, params: { promotion_id: promotion.id, id: promotion_rule.id }
      expect(response).to be_successful
    end

    it 'assigns the promotion rule' do
      get :edit, params: { promotion_id: promotion.id, id: promotion_rule.id }
      expect(assigns(:promotion_rule)).to eq(promotion_rule)
    end

    context 'with option value rule' do
      let!(:promotion_rule) { create(:promotion_rule_option_value, promotion: promotion) }

      it 'returns a successful response' do
        get :edit, params: { promotion_id: promotion.id, id: promotion_rule.id }
        expect(response).to be_successful
      end
    end
  end

  describe 'PATCH #update' do
    let!(:promotion_rule) { create(:promotion_rule_user, promotion: promotion) }
    let(:update_params) do
      {
        user_ids_to_add: [user.id]
      }
    end

    it 'updates the promotion rule' do
      patch :update, params: { promotion_id: promotion.id, id: promotion_rule.id, promotion_rule: update_params }
      promotion_rule.reload
      expect(promotion_rule.user_ids).to include(user.id)
    end

    it 'redirects to the promotion page' do
      patch :update, params: { promotion_id: promotion.id, id: promotion_rule.id, promotion_rule: update_params }
      expect(response).to redirect_to(spree.admin_promotion_path(promotion))
    end

    context 'with option value rule' do
      let!(:promotion_rule) { create(:promotion_rule_option_value, promotion: promotion) }
      let!(:option_value) { create(:option_value) }
      let(:rule_params) do
        {
          preferred_match_policy: 'any',
          preferred_eligible_values: [option_value.id]
        }
      end

      it 'updates the promotion rule' do
        patch :update, params: { promotion_id: promotion.id, id: promotion_rule.id, promotion_rule: rule_params }
        promotion_rule.reload
        expect(promotion_rule.preferred_eligible_values).to include(option_value.id.to_s)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:promotion_rule) { create(:promotion_rule, promotion: promotion) }

    it 'destroys the promotion rule' do
      expect {
        delete :destroy, params: { promotion_id: promotion.id, id: promotion_rule.id }
      }.to change(Spree::PromotionRule, :count).by(-1)
    end

    it 'redirects to the promotion page' do
      delete :destroy, params: { promotion_id: promotion.id, id: promotion_rule.id }
      expect(response).to redirect_to(spree.admin_promotion_path(promotion))
    end
  end

  describe 'helper methods' do
    it 'provides allowed_rule_types' do
      get :new, params: { promotion_id: promotion.id }
      expect(controller.send(:allowed_rule_types)).to eq(Spree.promotions.rules)
    end
  end
end
