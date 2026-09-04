require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::Orders::LabelsController, type: :controller do
  render_views

  include_context 'API v3 Seller'

  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end
  let(:token) do
    Spree::Api::V3::TestingSupport.generate_jwt(
      seller_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER
    )
  end

  let!(:order) { create(:order_ready_to_ship, store: store, seller: seller) }
  let(:fulfillment) { order.fulfillments.first }
  let(:signed_file) do
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("%PDF-1.4\n%label\n"), filename: 'label.pdf', content_type: 'application/pdf',
      service_name: Spree.private_storage_service_name
    ).signed_id
  end

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
    fulfillment.deliveries.destroy_all
  end

  it 'records a label the seller bought elsewhere' do
    post :create, params: {
      order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id,
      file: signed_file, tracking_number: 'SELLER-LBL-1', cost: '4.20', currency: 'USD'
    }, as: :json

    expect(response).to have_http_status(:created)
    expect(json_response['source']).to eq('uploaded')
    expect(json_response['download_url']).to include('/seller/')
    expect(fulfillment.reload.tracking).to eq('SELLER-LBL-1')
  end

  # Buying and refunding need the operator's carrier account, so the seller
  # branch offers neither: a request with no file has nothing to record.
  it 'refuses a purchase request' do
    post :create, params: { order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(fulfillment.reload.shipping_labels).to be_empty
  end

  it 'exposes no refund action at all' do
    expect(described_class.action_methods).not_to include('refund')
    expect(Spree::Core::Engine.routes.routes.map { |route| route.path.spec.to_s }).
      not_to include(a_string_matching(%r{/seller/.*labels/.*refund}))
  end

  it 'streams the label back' do
    label = create(:shipping_label, :uploaded, :with_file, owner: fulfillment)

    get :download, params: {
      order_id: order.prefixed_id, fulfillment_id: fulfillment.prefixed_id, id: label.prefixed_id
    }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include('%PDF')
  end
end
