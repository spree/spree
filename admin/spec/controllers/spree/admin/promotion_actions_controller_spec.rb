require 'spec_helper'

RSpec.describe Spree::Admin::PromotionActionsController, type: :controller do
  stub_authorization!

  render_views

  let(:user) { create(:admin_user) }
  let(:store) { @default_store }
  let(:promotion) { create(:promotion, stores: [store]) }

  before do
    allow(controller).to receive(:current_ability).and_call_original
  end

  describe 'GET #new' do
    it 'returns a successful response' do
      get :new, params: { promotion_id: promotion.id }
      expect(response).to be_successful
    end

    context 'when type is provided' do
      let(:action_type) { 'Spree::Promotion::Actions::CreateAdjustment' }

      it 'returns a successful response' do
        get :new, params: { promotion_id: promotion.id, promotion_action: { type: action_type } }
        expect(response).to be_successful
      end

      it 'loads the correct action type' do
        get :new, params: { promotion_id: promotion.id, promotion_action: { type: action_type } }
        expect(assigns(:promotion_action).class).to eq(action_type.constantize)
      end
    end
  end

  describe 'POST #create' do
    let(:action_type) { 'Spree::Promotion::Actions::CreateAdjustment' }
    let(:action_params) do
      {
        type: action_type,
        calculator_type: 'Spree::Calculator::FlatRate',
        calculator_attributes: {
          type: 'Spree::Calculator::FlatRate',
          preferred_amount: 20.0,
          preferred_currency: 'EUR'
        }
      }
    end

    it 'creates a new promotion action' do
      expect {
        post :create, params: { promotion_id: promotion.id, promotion_action: action_params }
      }.to change(Spree::PromotionAction, :count).by(1)

      expect(assigns(:promotion_action).calculator.preferred_amount).to eq(20.0)
      expect(assigns(:promotion_action).calculator.preferred_currency).to eq('EUR')
    end

    it 'redirects to the promotion page' do
      post :create, params: { promotion_id: promotion.id, promotion_action: action_params }
      expect(response).to redirect_to(spree.admin_promotion_path(promotion))
    end

    context 'with invalid action type' do
      let(:action_type) { 'InvalidActionType' }

      it 'raises an error' do
        expect {
          post :create, params: { promotion_id: promotion.id, promotion_action: action_params }
        }.to raise_error('Unknown promotion action type')
      end
    end
  end

  describe 'GET #edit' do
    let!(:promotion_action) { create(:promotion_action_create_adjustment, promotion: promotion) }

    it 'returns a successful response' do
      get :edit, params: { promotion_id: promotion.id, id: promotion_action.id }
      expect(response).to be_successful
    end

    it 'assigns the promotion action' do
      get :edit, params: { promotion_id: promotion.id, id: promotion_action.id }
      expect(assigns(:promotion_action)).to eq(promotion_action)
    end
  end

  describe 'PATCH #update' do
    let!(:promotion_action) { create(:promotion_action_create_adjustment, promotion: promotion) }
    let(:calculator) { promotion_action.calculator }
    let(:update_params) do
      {
        calculator_attributes: {
          id: calculator.id,
          preferred_amount: 20.0
        }
      }
    end

    it 'updates the promotion action' do
      patch :update, params: { promotion_id: promotion.id, id: promotion_action.id, promotion_action: update_params }
      calculator.reload
      expect(calculator.preferred_amount).to eq(20.0)
    end

    it 'redirects to the promotion page' do
      patch :update, params: { promotion_id: promotion.id, id: promotion_action.id, promotion_action: update_params }
      expect(response).to redirect_to(spree.admin_promotion_path(promotion))
    end

    context 'create line items type' do
      let!(:promotion_action) { create(:promotion_action_create_line_items, promotion: promotion) }
      let(:action_type) { 'Spree::Promotion::Actions::CreateLineItems' }
      let(:product) { create(:product, stores: [store]) }
      let(:variant) { create(:variant, product: product) }
      let(:action_params) do
        {
          type: action_type,
          promotion_action_line_items_attributes: {
            '0' => {
              promotion_action_id: promotion_action.id,
              variant_id: variant.id,
              quantity: 2,
              _destroy: nil
            }
          }
        }
      end

      it 'sets the promotion action line items' do
        patch :update, params: { promotion_id: promotion.id, id: promotion_action.id, promotion_action: action_params }
        expect(assigns(:promotion_action).promotion_action_line_items.first.variant_id).to eq(variant.id)
        expect(assigns(:promotion_action).promotion_action_line_items.first.quantity).to eq(2)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:promotion_action) { create(:promotion_action_create_adjustment, promotion: promotion) }

    it 'destroys the promotion action' do
      expect {
        delete :destroy, params: { promotion_id: promotion.id, id: promotion_action.id }
      }.to change(Spree::PromotionAction, :count).by(-1)
    end

    it 'redirects to the promotion page' do
      delete :destroy, params: { promotion_id: promotion.id, id: promotion_action.id }
      expect(response).to redirect_to(spree.admin_promotion_path(promotion))
    end
  end

  describe 'helper methods' do
    it 'provides allowed_action_types' do
      get :new, params: { promotion_id: promotion.id }
      expect(controller.send(:allowed_action_types)).to eq(Spree.promotions.actions)
    end
  end
end
