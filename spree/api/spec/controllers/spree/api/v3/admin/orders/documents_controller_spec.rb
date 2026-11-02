require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Orders::DocumentsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:order) { create(:completed_order_with_totals, store: store) }

  before do
    request.headers.merge!(headers)
    create_list(:order_document, 2, order: order)
  end

  describe 'GET #index' do
    it_behaves_like 'a list without N+1 queries' do
      subject { get :index, params: { order_id: order.prefixed_id }, as: :json }
    end

    it "is a 404 for another store's order" do
      get :index, params: { order_id: create(:completed_order_with_totals, store: create(:store)).prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH #update' do
    it 'never replaces the file' do
      document = order.order_documents.first
      blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new("%PDF-1.4\n"), filename: 'other.pdf', content_type: 'application/pdf',
                                                    service_name: Spree.private_storage_service_name)

      patch :update, params: { order_id: order.prefixed_id, id: document.prefixed_id, file_signed_id: blob.signed_id, label: 'Renamed' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(document.reload.label).to eq('Renamed')
      expect(document.file.blob).not_to eq(blob)
    end
  end

  describe 'DELETE #destroy' do
    it 'removes the document' do
      document = order.order_documents.first

      expect {
        delete :destroy, params: { order_id: order.prefixed_id, id: document.prefixed_id }, as: :json
      }.to change(Spree::OrderDocument, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
