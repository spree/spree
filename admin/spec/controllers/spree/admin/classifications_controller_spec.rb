require 'spec_helper'

RSpec.describe Spree::Admin::ClassificationsController, type: :controller do
  stub_authorization!

  render_views

  let(:store) { @default_store }
  let(:taxon) { create(:taxon, sort_order: sort_order, taxonomy: store.taxonomies.first) }
  let(:sort_order) { 'manual' }

  let(:product1) { create(:product, stores: [store]) }
  let(:product2) { create(:product, stores: [store]) }

  describe 'GET #index' do
    let!(:classifications) do
      [
        create(:classification, taxon: taxon, product: product1),
        create(:classification, taxon: taxon, product: product2)
      ]
    end

    subject { get :index, params: { taxon_id: taxon.to_param } }

    it 'returns a successful response' do
      subject
      expect(response).to have_http_status(:success)
    end

    it 'assigns @classifications' do
      subject
      expect(assigns(:classifications)).to contain_exactly(*classifications)
    end

    context 'when sort_order is best_selling' do
      let(:sort_order) { 'best-selling' }

      let!(:completed_order_1) { create(:completed_order_with_totals, variants: [product1.master, product2.master]) }
      let!(:completed_order_2) { create(:completed_order_with_totals, variants: [product2.master]) }

      it 'assigns @classifications' do
        subject
        expect(assigns(:classifications)).to eq([classifications[1], classifications[0]])
      end
    end
  end

  describe 'POST #create' do
    subject { post :create, params: { taxon_id: taxon.to_param, ids: [product1.id, product2.id], format: :turbo_stream } }

    it 'creates classifications' do
      expect { subject }.to change(Spree::Classification, :count).by(2)
    end

    it 'returns a successful response' do
      subject
      expect(response).to have_http_status(:success)
    end
  end

  describe 'PATCH #update' do
    let!(:classification) { create(:classification, taxon: taxon, product: product1, position: 1) }

    subject { patch :update, params: { taxon_id: taxon.to_param, id: classification.to_param, classification: { position: 2 }, format: :turbo_stream } }

    it 'updates the classification' do
      expect { subject }.to change { classification.reload.position }.from(1).to(2)
    end

    it 'returns a successful response' do
      subject
      expect(response).to have_http_status(:success)
    end
  end

  describe 'DELETE #destroy' do
    let!(:classification) { create(:classification, taxon: taxon, product: product1) }

    subject { delete :destroy, params: { taxon_id: taxon.to_param, id: classification.to_param, format: :turbo_stream } }

    it 'destroys the classification' do
      expect { subject }.to change(Spree::Classification, :count).by(-1)
    end

    it 'returns a successful response' do
      subject
      expect(response).to have_http_status(:success)
    end
  end
end
