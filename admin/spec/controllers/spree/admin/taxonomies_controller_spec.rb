require 'spec_helper'

describe Spree::Admin::TaxonomiesController do
  stub_authorization!

  describe '#edit' do
    let(:taxonomy) { create(:taxonomy) }

    before do
      get :edit, params: { id: taxonomy.id }
    end

    it 'redirects to taxonomy edit path' do
      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:edit)
    end
  end
end
