require 'spec_helper'

describe Spree::Admin::PropertiesController, type: :controller do
  stub_authorization!

  render_views

  let(:store) { Spree::Store.default }

  before do
    allow(controller).to receive(:current_store).and_return(store)
  end

  describe '#index' do
    let!(:property) { create(:property, name: 'Ingredients', presentation: 'Product Ingredients') }

    it 'renders index' do
      get :index
      expect(response).to have_http_status(:ok)

      expect(assigns(:collection).to_a.count).to eq(1)
      expect(assigns(:collection).to_a).to eq([property])
    end
  end

  describe '#create ' do
    it 'creates a property' do
      expect { post :create, params: {property: {name: 'New Property', presentation: 'New Presentation'}} }.to change(Spree::Property, :count).by(1)
    end
  end

  describe '#update' do
    let(:property) { create(:property) }

    it 'updates the property' do
      put :update, params: {id: property.id, property: { name: 'New Name'}}

      expect(property.reload.name).to eq('new-name')
    end

    it 'can set property position' do
      put :update, params: {id: property.id, property: { position: 2 }}

      expect(property.reload.position).to eq(2)
    end
  end
end
