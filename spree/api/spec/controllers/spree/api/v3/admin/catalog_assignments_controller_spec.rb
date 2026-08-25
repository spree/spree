require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CatalogAssignmentsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:catalog) { create(:catalog, store: store) }
  let!(:assignment) { create(:catalog_assignment, catalog: catalog) }

  before { request.headers.merge!(headers) }

  describe 'DELETE #destroy' do
    it 'withdraws the catalog from the audience' do
      delete :destroy, params: { id: assignment.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(catalog.catalog_assignments.reload).to be_empty
    end

    it '404s an assignment of another store catalog' do
      foreign = create(:catalog_assignment, catalog: create(:catalog, store: create(:store)))

      delete :destroy, params: { id: foreign.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
