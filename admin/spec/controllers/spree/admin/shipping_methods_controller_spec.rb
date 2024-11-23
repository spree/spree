require 'spec_helper'

describe Spree::Admin::ShippingMethodsController, type: :controller do
  stub_authorization!

  let(:store) { Spree::Store.default }
  let!(:shipping_category) { create(:shipping_category) }

  describe '#index' do
    it 'renders the index template' do
      get :index
      expect(response.status).to eq(200)
    end
  end

  describe '#new' do
    it 'assigns default values' do
      get :new
      expect(assigns(:shipping_method).display_on).to eq('both')
      expect(assigns(:shipping_method).shipping_categories).to eq([shipping_category])
      expect(assigns(:shipping_method).zone_ids).to eq(store.supported_shipping_zones.map(&:id))
      expect(assigns(:shipping_method).calculator_type).to eq(Spree::ShippingMethod.calculators.first.name)
    end
  end

  describe '#create' do
    let(:zone) { create(:zone) }
    let(:shipping_method_attributes) { attributes_for(:shipping_method, zone_ids: [zone.id], shipping_category_ids: [shipping_category.id], calculator_type: 'Spree::Calculator::Shipping::FlatRate') }

    it 'creates a new shipping method' do
      expect { post :create, params: { shipping_method: shipping_method_attributes } }.to change(Spree::ShippingMethod, :count).by(1)
    end
  end
end
