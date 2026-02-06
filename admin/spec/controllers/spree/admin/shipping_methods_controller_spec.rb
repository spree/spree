require 'spec_helper'

describe Spree::Admin::ShippingMethodsController, type: :controller do
  stub_authorization!

  render_views

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
    let(:shipping_method_attributes) { attributes_for(:shipping_method, zone_ids: [zone.id], estimated_transit_business_days_min: 1, estimated_transit_business_days_max: 2, shipping_category_ids: [shipping_category.id], calculator_type: 'Spree::Calculator::Shipping::FlatRate', calculator_attributes: { preferred_amount: 10, preferred_currency: 'EUR' }) }

    it 'creates a new shipping method' do
      expect { post :create, params: { shipping_method: shipping_method_attributes } }.to change(Spree::ShippingMethod, :count).by(1)

      shipping_method = Spree::ShippingMethod.last
      expect(shipping_method.zone_ids).to eq([zone.id])
      expect(shipping_method.shipping_category_ids).to eq([shipping_category.id])
      expect(shipping_method.estimated_transit_business_days_min).to eq(1)
      expect(shipping_method.estimated_transit_business_days_max).to eq(2)
      expect(shipping_method.calculator.preferred_amount).to eq(10)
      expect(shipping_method.calculator.preferred_currency).to eq('EUR')
    end
  end

  describe '#edit' do
    let(:shipping_method) { create(:shipping_method) }

    it 'renders the edit template' do
      get :edit, params: { id: shipping_method.to_param }
      expect(response.status).to eq(200)
    end
  end

  describe '#update' do
    let(:shipping_method) { create(:shipping_method) }
    let(:zone) { create(:zone) }
    let(:new_attributes) do
      {
        name: 'Updated Method',
        zone_ids: [zone.id],
        estimated_transit_business_days_min: 3,
        estimated_transit_business_days_max: 5,
        shipping_category_ids: [shipping_category.id],
        calculator_type: 'Spree::Calculator::Shipping::FlatRate',
        calculator_attributes: {
          type: 'Spree::Calculator::Shipping::FlatRate',
          preferred_amount: 20,
          preferred_currency: 'USD'
        }
      }
    end

    it 'updates the shipping method' do
      put :update, params: { id: shipping_method.to_param, shipping_method: new_attributes }

      shipping_method.reload
      expect(shipping_method.name).to eq('Updated Method')
      expect(shipping_method.zone_ids).to eq([zone.id])
      expect(shipping_method.estimated_transit_business_days_min).to eq(3)
      expect(shipping_method.estimated_transit_business_days_max).to eq(5)
      expect(shipping_method.calculator.preferred_amount).to eq(20)
      expect(shipping_method.calculator.preferred_currency).to eq('USD')
      expect(response).to redirect_to(spree.edit_admin_shipping_method_path(shipping_method))
    end
  end

  describe '#destroy' do
    let!(:shipping_method) { create(:shipping_method) }

    it 'deletes the shipping method' do
      expect {
        delete :destroy, params: { id: shipping_method.to_param }
      }.to change(Spree::ShippingMethod, :count).by(-1)

      expect(response).to redirect_to(spree.admin_shipping_methods_path)
    end
  end
end
