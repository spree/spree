require 'spec_helper'

RSpec.describe Spree::Admin::JsonPreviewsController, type: :controller do
  stub_authorization!
  render_views

  let(:product) { create(:product) }
  let(:resource_type) { 'Spree::Product' }

  describe 'GET #show' do
    it 'assigns @resource and renders the show template' do
      get :show, params: { resource_type: resource_type, id: product.slug }
      expect(response).to render_template(:show)
      expect(assigns(:resource)).to eq(product)
      expect(assigns(:api_type)).to eq(:storefront)
    end

    context 'with api_type param' do
      it 'assigns @api_type as symbol' do
        get :show, params: { resource_type: resource_type, id: product.slug, api_type: 'platform' }
        expect(assigns(:api_type)).to eq(:platform)
      end
    end

    context 'when resource_type is missing' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          get :show, params: { id: product.slug, resource_type: '' }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when resource_type is invalid' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          get :show, params: { resource_type: 'InvalidType', id: product.slug }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
