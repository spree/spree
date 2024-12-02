require 'spec_helper'

RSpec.describe Spree::Admin::ClassificationsController, type: :controller do
  let(:store) { Spree::Store.default }

  stub_authorization!

  render_views

  let(:taxon) { create(:taxon) }
  let(:product1) { create(:product) }
  let(:product2) { create(:product) }

  describe 'GET #index' do
    let!(:classifications) do
      [create(:classification, taxon: taxon, product: product1),
       create(:classification, taxon: taxon, product: product2)]
    end

    subject { get :index, params: { taxon_id: taxon.id } }

    it 'returns a successful response' do
      subject
      expect(response).to have_http_status(:success)
    end

    it 'assigns @classifications' do
      subject
      expect(assigns(:classifications)).to contain_exactly(*classifications)
    end
  end

  describe 'POST #create' do
    subject { post :create, params: { taxon_id: taxon.id, product_ids: [product1.id, product2.id], format: :turbo_stream } }

    it 'creates classifications' do
      expect { subject }.to change(Spree::Classification, :count).by(2)
    end

    it 'returns a successful response' do
      subject
      expect(response).to have_http_status(:success)
    end
  end

  describe 'DELETE #destroy' do
    let!(:classification) { create(:classification, taxon: taxon, product: product1) }

    subject { delete :destroy, params: { taxon_id: taxon.id, id: classification.id, format: :turbo_stream } }

    it 'destroys the classification' do
      expect { subject }.to change(Spree::Classification, :count).by(-1)
    end

    it 'returns a successful response' do
      subject
      expect(response).to have_http_status(:success)
    end
  end
end
