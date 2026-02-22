require 'spec_helper'

RSpec.describe Spree::Admin::PriceRulesController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }
  let(:price_list) { create(:price_list, store: store) }

  describe 'GET #new' do
    context 'without type parameter' do
      subject { get :new, params: { price_list_id: price_list.to_param } }

      it 'renders the rule type selection' do
        subject

        expect(response).to render_template(:new)
        expect(assigns[:price_rule]).to be_a(Spree::PriceRule)
        expect(assigns[:price_rule].type).to be_nil
      end
    end

    context 'with type parameter' do
      subject { get :new, params: { price_list_id: price_list.to_param, price_rule: { type: 'Spree::PriceRules::ZoneRule' } } }

      it 'renders the form for the selected type' do
        subject

        expect(response).to render_template(:new)
        expect(assigns[:price_rule]).to be_a(Spree::PriceRules::ZoneRule)
      end
    end
  end

  describe 'POST #create' do
    subject { post :create, params: params }

    let(:params) do
      {
        price_list_id: price_list.to_param,
        price_rule: {
          type: 'Spree::PriceRules::VolumeRule',
          preferred_min_quantity: 10,
          preferred_max_quantity: 100,
          preferred_apply_to: 'line_item'
        }
      }
    end

    it 'creates a new price rule' do
      expect { subject }.to change(Spree::PriceRule, :count).by(1)
    end

    it 'creates the correct rule type' do
      subject

      rule = Spree::PriceRule.last
      expect(rule).to be_a(Spree::PriceRules::VolumeRule)
      expect(rule.price_list).to eq(price_list)
      expect(rule.preferred_min_quantity).to eq(10)
      expect(rule.preferred_max_quantity).to eq(100)
    end

    it 'redirects to the price list' do
      subject

      expect(response).to redirect_to(spree.admin_price_list_path(price_list))
    end
  end

  describe 'GET #edit' do
    subject { get :edit, params: { price_list_id: price_list.to_param, id: price_rule.to_param } }

    let!(:price_rule) { create(:volume_price_rule, price_list: price_list) }

    it 'renders the edit form' do
      subject

      expect(response).to render_template(:edit)
      expect(assigns[:price_rule]).to eq(price_rule)
    end
  end

  describe 'PUT #update' do
    subject { put :update, params: params }

    let!(:price_rule) { create(:volume_price_rule, price_list: price_list, preferred_min_quantity: 5) }

    let(:params) do
      {
        price_list_id: price_list.to_param,
        id: price_rule.to_param,
        price_rule: {
          preferred_min_quantity: 20
        }
      }
    end

    it 'updates the price rule' do
      subject
      price_rule.reload

      expect(price_rule.preferred_min_quantity).to eq(20)
    end

    it 'redirects to the price list' do
      subject

      expect(response).to redirect_to(spree.admin_price_list_path(price_list))
    end
  end

  describe 'DELETE #destroy' do
    subject { delete :destroy, params: { price_list_id: price_list.to_param, id: price_rule.to_param } }

    let!(:price_rule) { create(:volume_price_rule, price_list: price_list) }

    it 'destroys the price rule' do
      expect { subject }.to change(Spree::PriceRule, :count).by(-1)
    end

    it 'redirects to the price list' do
      subject

      expect(response).to redirect_to(spree.admin_price_list_path(price_list))
    end
  end
end
