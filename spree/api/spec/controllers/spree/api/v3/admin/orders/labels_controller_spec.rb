require 'spec_helper'
require 'spree/testing_support/label_provider'

RSpec.describe Spree::Api::V3::Admin::Orders::LabelsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:order) { create(:order_ready_to_ship, store: store) }
  let!(:fulfillment) { order.fulfillments.first }
  let(:signed_file) do
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("%PDF-1.4\n%label\n"), filename: 'label.pdf', content_type: 'application/pdf',
      service_name: Spree.private_storage_service_name
    ).signed_id
  end

  before do
    request.headers.merge!(headers)
    Spree::TestingSupport::LabelProvider.reset!
    allow(SsrfFilter).to receive(:get).and_raise(SocketError.new('offline'))
  end

  describe 'POST #create' do
    context 'buying through the provider' do
      before do
        allow_any_instance_of(Spree::Fulfillment).to receive(:provider).and_return(Spree::TestingSupport::LabelProvider.new)
        fulfillment.deliveries.destroy_all
      end

      it 'buys the label and answers with it' do
        post :create, params: { order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id }, as: :json

        expect(response).to have_http_status(:created)
        expect(json_response['id']).to start_with('lbl_')
        expect(json_response['source']).to eq('purchased')
        expect(json_response['status']).to eq('purchased')
        expect(json_response['cost']).to eq('7.25')
        expect(json_response['owner_type']).to eq('fulfillment')
        expect(json_response['download_url']).to include('/labels/')
        expect(fulfillment.reload.tracking).to eq('1Z879E930346834440')
      end

      it 'refuses a second label while one is active' do
        post :create, params: { order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id }, as: :json
        post :create, params: { order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'recording an uploaded label' do
      before { fulfillment.deliveries.destroy_all }

      it 'records the file, the cost and the consignment' do
        post :create, params: {
          order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id,
          file: signed_file, tracking_number: '1Z879E930346834440', cost: '6.50', currency: 'USD'
        }, as: :json

        expect(response).to have_http_status(:created)
        expect(json_response['source']).to eq('uploaded')
        expect(json_response['display_cost']).to eq('$6.50')
        expect(fulfillment.reload.tracking).to eq('1Z879E930346834440')
      end

      it 'refuses an upload with no tracking number' do
        post :create, params: {
          order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id, file: signed_file
        }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'GET #download' do
    it 'streams the stored file rather than redirecting to storage' do
      label = create(:shipping_label, :with_file, owner: fulfillment)

      get :download, params: {
        order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id, id: label.prefixed_id
      }

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Disposition']).to include('attachment')
      expect(response.body).to include('%PDF')
    end

    it 'proxies the carrier copy while the fetch is pending' do
      label = create(:shipping_label, owner: fulfillment, metadata: { 'file_url' => 'https://carrier.example/l.pdf' })

      get :download, params: {
        order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id, id: label.prefixed_id
      }

      expect(response).to redirect_to('https://carrier.example/l.pdf')
    end
  end

  describe 'PATCH #refund' do
    before do
      allow_any_instance_of(Spree::Fulfillment).to receive(:provider).and_return(Spree::TestingSupport::LabelProvider.new)
    end

    it 'refunds a purchased label and drops its unshipped consignment' do
      label = create(:shipping_label, :with_delivery, owner: fulfillment)

      patch :refund, params: {
        order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id, id: label.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('refunded')
      expect(label.reload.delivery).to be_nil
    end

    it 'refuses an uploaded label' do
      label = create(:shipping_label, :uploaded, owner: fulfillment)

      patch :refund, params: {
        order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id, id: label.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes an uploaded label and its consignment' do
      label = create(:shipping_label, :uploaded, :with_delivery, owner: fulfillment)

      delete :destroy, params: {
        order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id, id: label.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::ShippingLabel.exists?(label.id)).to be(false)
    end

    it 'refuses to delete a purchased label' do
      label = create(:shipping_label, owner: fulfillment)

      delete :destroy, params: {
        order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id, id: label.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    # A journey that happened is a fact: deleting the label a parcel shipped
    # under must not erase where that parcel went.
    it 'keeps the consignment once the parcel has shipped' do
      label = create(:shipping_label, :uploaded, :with_delivery, owner: fulfillment)
      fulfillment.update!(status: 'fulfilled', fulfilled_at: Time.current)

      delete :destroy, params: {
        order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id, id: label.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(Spree::ShippingLabel.exists?(label.id)).to be(true)
      expect(fulfillment.reload.deliveries).to be_present
    end
  end

  describe 'return labels' do
    let(:return_record) { create(:return, order: create(:shipped_order, store: store)) }

    it 'records an uploaded label on the return' do
      post :create, params: {
        order_id: return_record.order.prefixed_id, return_id: return_record.prefixed_id,
        file: signed_file, tracking_number: 'RET-1'
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['owner_type']).to eq('return')
      expect(json_response['download_url']).to include('/returns/')
      expect(return_record.reload.active_shipping_label).to be_present
    end
  end

  it 'answers 404 for a fulfillment on another store order' do
    other = create(:order_ready_to_ship, store: create(:store))

    get :index, params: { order_id: other.prefixed_id, fulfillment_id: other.fulfillments.first.prefixed_id }, as: :json

    expect(response).to have_http_status(:not_found)
  end
end
