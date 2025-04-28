require 'spec_helper'

describe Spree::Admin::TaxonomiesController do
  stub_authorization!

  describe '#edit' do
    let(:taxonomy) { create(:taxonomy) }
    let(:taxonomy_id) { taxonomy.id }

    before do
      get :edit, params: { id: taxonomy_id }
    end

    it 'redirects to taxonomy taxon path' do
      expect(response).to redirect_to(spree.admin_taxonomy_taxon_path(taxonomy, taxonomy.root.id))
    end

    context 'when taxonomy not found' do
      let(:taxonomy_id) { 'not_existing' }

      it 'redirects to admin taxonomies path' do
        expect(response).to redirect_to(spree.admin_taxonomies_path)
      end
    end
  end
end
