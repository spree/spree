require 'spec_helper'

describe Spree::Admin::TaxonomiesController do
  stub_authorization!
  render_views

  describe '#index' do
    subject { get :index }

    it 'renders index taxonomy view' do
      subject

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:index)
    end
  end

  describe '#new' do
    subject { get :new }

    it 'renders new taxonomy view' do
      subject

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
    end
  end

  describe '#create' do
    subject { post :create, params: { taxonomy: { name: 'New Taxonomy' } } }

    it 'creates a new taxonomy' do
      expect { subject }.to change(Spree::Taxonomy, :count).by(1)
      expect(response).to redirect_to spree.admin_taxonomy_path(Spree::Taxonomy.last)
    end
  end

  describe '#edit' do
    let(:taxonomy) { create(:taxonomy) }

    before do
      get :edit, params: { id: taxonomy.to_param }
    end

    it 'renders edit taxonomy view' do
      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:edit)
    end
  end

  describe '#update' do
    subject { put :update, params: { id: taxonomy.to_param, taxonomy: { name: 'New Name' } } }

    let(:taxonomy) { create(:taxonomy) }

    it 'updates the taxonomy' do
      subject

      expect(response).to redirect_to spree.admin_taxonomy_path(taxonomy)
    end

    context 'update position' do
      subject { put :update, params: { id: taxonomy.to_param, taxonomy: { position: 2 } }, format: :turbo_stream }

      it 'updates the taxonomy position' do
        subject
        expect(taxonomy.reload.position).to eq(2)
      end
    end
  end

  describe '#destroy' do
    subject { delete :destroy, params: { id: taxonomy.to_param } }

    let!(:taxonomy) { create(:taxonomy) }

    it 'destroys the taxonomy' do
      expect { subject }.to change(Spree::Taxonomy, :count).by(-1)
      expect(response).to redirect_to spree.admin_taxonomies_path
    end
  end
end
