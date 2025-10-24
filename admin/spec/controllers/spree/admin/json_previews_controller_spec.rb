require 'spec_helper'

RSpec.describe Spree::Admin::JsonPreviewsController, type: :controller do
  stub_authorization!
  render_views

  let(:product) { create(:product) }
  let(:resource_type) { 'Spree::Product' }

  describe 'GET #show' do
    it 'assigns @object and renders the show template' do
      get :show, params: { resource_type: resource_type, id: product.id }
      expect(response).to render_template(:show)
      expect(assigns(:object)).to eq(product)
    end

    context 'when resource_type is missing' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          get :show, params: { id: product.id, resource_type: '' }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when resource_type is invalid' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          get :show, params: { resource_type: 'InvalidType', id: product.id }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
