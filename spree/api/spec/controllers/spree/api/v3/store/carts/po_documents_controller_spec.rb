require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Carts::PoDocumentsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:order) { create(:cart_with_line_items, customer: user, store: store) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  def attach_document!(cart = order)
    cart.po_document.attach(
      io: StringIO.new('%PDF-1.4 purchase order'),
      filename: 'po.pdf',
      content_type: 'application/pdf'
    )
  end

  describe 'POST #create' do
    let(:blob_params) do
      { filename: 'po.pdf', byte_size: 23, checksum: Digest::MD5.base64digest('%PDF-1.4 purchase order'),
        content_type: 'application/pdf' }
    end

    it 'returns an upload target and a signed id' do
      post :create, params: { cart_id: order.prefixed_id, blob: blob_params }

      expect(response).to have_http_status(:created)
      expect(json_response['signed_id']).to be_present
      expect(json_response['direct_upload']['url']).to be_present
    end

    # A purchase order carries the buyer's prices and terms, and attaching a
    # signed id never moves a blob between services.
    it 'mints the blob on private storage' do
      post :create, params: { cart_id: order.prefixed_id, blob: blob_params }

      blob = ActiveStorage::Blob.find_signed!(json_response['signed_id'])
      expect(blob.service_name).to eq(Spree.private_storage_service_name.to_s)
    end
  end

  describe 'GET #show' do
    it 'streams the document back' do
      attach_document!

      get :show, params: { cart_id: order.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Disposition']).to include('po.pdf')
      expect(response.body).to include('purchase order')
    end

    it 'reports nothing when no document was uploaded' do
      get :show, params: { cart_id: order.prefixed_id }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE #destroy' do
    # Detaches rather than purges: completion attaches the same blob to the
    # order, so destroying the bytes would take the placed order's copy too.
    it 'detaches the document without destroying the blob' do
      attach_document!
      blob_id = order.po_document.blob_id

      delete :destroy, params: { cart_id: order.prefixed_id }

      expect(response).to have_http_status(:no_content)
      expect(order.reload.po_document).not_to be_attached
      expect(ActiveStorage::Blob.exists?(blob_id)).to be(true)
    end

    it 'reports nothing when there is no document' do
      delete :destroy, params: { cart_id: order.prefixed_id }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'reaching another buyer\'s cart' do
    let(:other_cart) { create(:cart_with_line_items, customer: create(:user), store: store) }

    it 'refuses to presign against it' do
      post :create, params: { cart_id: other_cart.prefixed_id,
                              blob: { filename: 'po.pdf', byte_size: 1, checksum: 'x', content_type: 'application/pdf' } }

      expect(response).not_to have_http_status(:created)
    end
  end
end
