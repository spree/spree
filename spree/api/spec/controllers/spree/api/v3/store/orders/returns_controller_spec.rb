require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Orders::ReturnsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:order) { create(:shipped_order, user: user, store: store) }
  let(:fulfillment_item) { order.fulfillment_items.first }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'POST #create' do
    it 'lets a customer open a return on their own order' do
      post :create, params: {
        order_id: order.to_param,
        memo: 'Wrong size',
        items: [{ fulfillment_item_id: fulfillment_item.prefixed_id, quantity: 1 }]
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['status']).to eq('requested')
      expect(json_response['number']).to start_with('RET')
    end

    it 'does not expose staff-only fields to the customer' do
      post :create, params: {
        order_id: order.to_param,
        items: [{ fulfillment_item_id: fulfillment_item.prefixed_id, quantity: 1 }]
      }, as: :json

      expect(json_response).not_to have_key('memo')
      expect(json_response).not_to have_key('created_at')
      expect(json_response).not_to have_key('created_by_id')
    end

    it 'rejects returning more than was fulfilled' do
      post :create, params: {
        order_id: order.to_param,
        items: [{ fulfillment_item_id: fulfillment_item.prefixed_id, quantity: 99 }]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    # Return eligibility is store policy, enforced through the hook rather
    # than in core.
    it 'surfaces a validate hook rejection' do
      Spree.hooks.register('returns.create.validate') { |workflow| workflow.reject!('Return window closed') }

      post :create, params: {
        order_id: order.to_param,
        items: [{ fulfillment_item_id: fulfillment_item.prefixed_id, quantity: 1 }]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    ensure
      Spree.hooks.clear!
    end
  end

  describe 'GET #index' do
    it 'lists the customer own returns' do
      create(:return, store: store, order: order)

      get :index, params: { order_id: order.to_param }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].length).to eq(1)
    end
  end

  describe 'GET #show' do
    it 'returns one record' do
      return_record = create(:return, store: store, order: order)

      get :show, params: { order_id: order.to_param, id: return_record.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(return_record.prefixed_id)
    end
  end

  describe 'authorization' do
    it 'does not expose another customer order' do
      other_order = create(:shipped_order, store: store, user: create(:user))

      get :index, params: { order_id: other_order.to_param }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
  describe 'GET #label' do
    let(:return_record) { create(:return, order: order) }

    it 'streams the return label to the order customer' do
      create(:shipping_label, :with_file, owner: return_record, store: store)

      get :label, params: { order_id: order.to_param, id: return_record.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Disposition']).to include('attachment')
      expect(response.body).to include('%PDF')
    end

    it 'is missing when no label was bought' do
      get :label, params: { order_id: order.to_param, id: return_record.prefixed_id }

      expect(response).to have_http_status(:not_found)
    end

    # The label row is merchant data — cost, provider ids — so only the file
    # is ever reachable from the storefront.
    it 'never serializes the label onto the return' do
      create(:shipping_label, :with_file, owner: return_record, store: store)

      get :show, params: { order_id: order.to_param, id: return_record.prefixed_id }, as: :json

      expect(json_response).not_to have_key('labels')
      expect(json_response).not_to have_key('shipping_labels')
    end
  end
end
