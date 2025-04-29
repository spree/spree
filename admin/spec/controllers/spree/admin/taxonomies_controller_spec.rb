require 'spec_helper'

describe Spree::Admin::TaxonomiesController do
  stub_authorization!
  render_views

  describe '#edit' do
    let(:taxonomy) { create(:taxonomy) }

    before do
      get :edit, params: { id: taxonomy.id }
    end

    it 'renders edit taxonomy view' do
      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:edit)
    end
  end
end
