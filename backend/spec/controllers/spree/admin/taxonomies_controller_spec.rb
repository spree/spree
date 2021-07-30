require 'spec_helper'

describe Spree::Admin::TaxonomiesController, type: :controller do
  stub_authorization!

  let(:store) { create(:store) }
  let(:new_store) { create(:store) }
  let!(:taxonomy_1) { create(:taxonomy, store: store) }
  let!(:taxonomy_2) { create(:taxonomy, store: store) }
  let!(:taxonomy_3) { create(:taxonomy) }

  before do
    allow_any_instance_of(described_class).to receive(:current_store).and_return(store)
  end

  describe '#index' do
    it 'should assign only the store credits for user and current store' do
      get :index
      expect(assigns(:collection)).to include taxonomy_1
      expect(assigns(:collection)).to include taxonomy_2
      expect(assigns(:collection)).not_to include taxonomy_3
    end
  end

  context '#new' do
    it 'should create taxonomy' do
      get :new
      expect(response.status).to eq(200)
    end
  end

  describe '#create' do
    let(:request) { post :create, params: { taxonomy: { name: 'Shirts' } } }

    it 'should create taxonomy for current store' do
      expect{ request }.to change { store.taxonomies.count }.by(1)
      expect(response).to be_redirect
    end

    context 'different store' do
      subject(:create_request) { post(:create, params: {taxonomy: {name: 'Bags'}}) }

      before do
        allow_any_instance_of(described_class).to receive(:current_store).and_return(new_store)
      end

      it 'should not create taxonomy for store' do
        expect{ subject }.not_to change { store.taxonomies.reload.count }
        expect(response).to be_redirect
      end

      it 'should create taxonomy for new store' do
        expect{ subject }.to change { new_store.taxonomies.reload.count }.by(1)
        expect(response).to be_redirect
      end
    end
  end

  describe '#update' do
    it 'should allow to update current store taxonomy' do
      expect{ put(:update, params: { id: taxonomy_1.id, taxonomy: { name: 'Beverages' } }) }.to change{taxonomy_1.reload.name}.to('Beverages')
    end

    it 'should not allow to update not current store taxonomy' do
      expect{ put(:update, params: { id: taxonomy_3.id, taxonomy: { name: 'Shoes' } }) }.not_to change{taxonomy_3.reload.name}
    end
  end

  describe '#destroy' do
    before { delete :destroy, params: { id: taxonomy.id } }

    context 'when current store taxonomy' do
      let(:taxonomy) { taxonomy_1 }

      it 'should be able to destroy taxonomy' do
        expect(assigns(:object)).to eq(taxonomy)
        expect(response).to have_http_status(:found)
        expect(flash[:success]).to eq("Taxonomy \"#{taxonomy.name}\" has been successfully removed!")
      end
    end

    context 'when not current store taxonomy' do
      let(:taxonomy) { taxonomy_3 }

      it 'should be able to destroy taxonomy' do
        expect(assigns(:object)).to be_nil
        expect(flash[:error]).to eq("Taxonomy is not found")
      end
    end
  end
end
