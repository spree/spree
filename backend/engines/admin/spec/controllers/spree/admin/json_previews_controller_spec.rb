require 'spec_helper'

RSpec.describe Spree::Admin::JsonPreviewsController, type: :controller do
  stub_authorization!
  render_views

  describe 'GET #show' do
    context 'with a FriendlyId model' do
      let(:product) { create(:product) }

      it 'renders the show template' do
        get :show, params: { resource_type: 'Spree::Product', id: product.prefixed_id }
        expect(response).to render_template(:show)
        expect(assigns(:object)).to eq(product)
      end
    end

    context 'with a non-FriendlyId model' do
      let(:order) { create(:order) }

      it 'renders the show template' do
        get :show, params: { resource_type: 'Spree::Order', id: order.prefixed_id }
        expect(response).to render_template(:show)
        expect(assigns(:object)).to eq(order)
      end
    end

    context 'when resource_type is missing' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          get :show, params: { resource_type: '', id: 'fake_id' }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when resource_type is invalid' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          get :show, params: { resource_type: 'InvalidType', id: 'fake_id' }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when resource_type is a non-Spree class' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          get :show, params: { resource_type: 'String', id: 'fake_id' }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end
  end
end
