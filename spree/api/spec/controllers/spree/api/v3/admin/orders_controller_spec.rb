require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::OrdersController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:order) { create(:order, store: store, state: 'cart') }

  describe 'GET #index' do
    subject { get :index, params: {}, as: :json }

    before { request.headers.merge!(headers) }

    it 'returns orders list' do
      subject

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].length).to eq(1)
      expect(json_response['data'].first['id']).to eq(order.prefixed_id)
    end

    it 'includes admin-only fields' do
      subject

      data = json_response['data'].first
      expect(data).to have_key('channel')
      expect(data).to have_key('considered_risky')
    end

    it 'returns pagination metadata' do
      subject

      expect(json_response['meta']).to include('page', 'limit', 'count', 'pages')
    end

    context 'with ransack filtering' do
      let!(:completed_order) { create(:completed_order_with_totals, store: store) }

      it 'filters by state' do
        get :index, params: { q: { state_eq: 'complete' } }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].length).to eq(1)
        expect(json_response['data'].first['id']).to eq(completed_order.prefixed_id)
      end
    end

    context 'without authentication' do
      let(:headers) { {} }

      it 'returns 401 unauthorized' do
        subject
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #show' do
    subject { get :show, params: { id: order.prefixed_id }, as: :json }

    before { request.headers.merge!(headers) }

    it 'returns the order' do
      subject

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(order.prefixed_id)
      expect(json_response['number']).to eq(order.number)
    end

    it 'includes admin-only fields' do
      subject

      expect(json_response).to have_key('channel')
      expect(json_response).to have_key('considered_risky')
      expect(json_response).to have_key('internal_note')
    end

    context 'with non-existent order' do
      it 'returns 404' do
        get :show, params: { id: 'or_nonexistent' }, as: :json
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST #create' do
    subject { post :create, params: create_params, as: :json }

    before { request.headers.merge!(headers) }

    let(:create_params) { { email: 'test@example.com' } }

    it 'creates a draft order' do
      expect { subject }.to change(Spree::Order, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['email']).to eq('test@example.com')
      expect(json_response['state']).to eq('cart')
    end

    context 'with user assignment' do
      let(:customer) { create(:user) }
      let(:create_params) { { user_id: customer.prefixed_id } }

      it 'creates order assigned to the user' do
        subject

        expect(response).to have_http_status(:created)
        created_order = Spree::Order.find_by_prefix_id(json_response['id'])
        expect(created_order.user).to eq(customer)
      end
    end
  end

  describe 'PATCH #update' do
    subject { patch :update, params: { id: order.prefixed_id, email: 'updated@example.com' }, as: :json }

    before { request.headers.merge!(headers) }

    it 'updates the order' do
      subject

      expect(response).to have_http_status(:ok)
      expect(json_response['email']).to eq('updated@example.com')
    end
  end

  describe 'DELETE #destroy' do
    subject { delete :destroy, params: { id: order.prefixed_id }, as: :json }

    before { request.headers.merge!(headers) }

    it 'deletes a draft order' do
      subject
      expect(response).to have_http_status(:no_content)
    end

    context 'with completed order' do
      let!(:order) { create(:completed_order_with_totals, store: store) }

      it 'returns 403 (cannot delete completed orders)' do
        subject
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PATCH #cancel' do
    let!(:order) { create(:completed_order_with_totals, store: store) }

    subject { patch :cancel, params: { id: order.prefixed_id }, as: :json }

    before { request.headers.merge!(headers) }

    it 'cancels the order' do
      subject

      expect(response).to have_http_status(:ok)
      expect(json_response['state']).to eq('canceled')
    end
  end

  describe 'PATCH #approve' do
    let!(:order) { create(:completed_order_with_totals, store: store) }

    subject { patch :approve, params: { id: order.prefixed_id }, as: :json }

    before { request.headers.merge!(headers) }

    it 'approves the order' do
      subject

      expect(response).to have_http_status(:ok)
      expect(json_response['approved_at']).to be_present
    end
  end

  describe 'PATCH #resume' do
    let!(:order) { create(:completed_order_with_totals, store: store) }

    subject { patch :resume, params: { id: order.prefixed_id }, as: :json }

    before do
      request.headers.merge!(headers)
      order.canceled_by(admin_user)
    end

    it 'resumes the canceled order' do
      subject

      expect(response).to have_http_status(:ok)
      expect(json_response['state']).to eq('resumed')
    end
  end

  describe 'POST #resend_confirmation' do
    let!(:order) { create(:completed_order_with_totals, store: store) }

    subject { post :resend_confirmation, params: { id: order.prefixed_id }, as: :json }

    before { request.headers.merge!(headers) }

    it 'returns the order' do
      subject

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(order.prefixed_id)
    end
  end
end
