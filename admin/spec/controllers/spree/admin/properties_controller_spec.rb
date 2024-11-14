require 'spec_helper'

describe Spree::Admin::PropertiesController, type: :controller do
  stub_authorization!

  let(:store) { Spree::Store.default }

  describe '#index' do
    let!(:property) { create(:property, name: 'Ingredients', presentation: 'Product Ingredients') }

    it 'renders index' do
      get :index
      expect(response).to have_http_status(:ok)

      expect(assigns(:collection).to_a.count).to eq(1)
      expect(assigns(:collection).to_a).to eq([property])
    end
  end
end
