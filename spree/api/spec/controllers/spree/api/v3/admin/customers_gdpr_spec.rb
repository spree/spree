require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CustomersController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:customer) { create(:user, email: 'buyer@example.com', first_name: 'Ada') }

  before { request.headers.merge!(headers) }

  describe 'GET #export' do
    it 'returns the data the store holds about the customer' do
      get :export, params: { id: customer.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response.dig('account', 'email')).to eq('buyer@example.com')
    end

    it 'includes the sections a subject access request has to answer' do
      get :export, params: { id: customer.prefixed_id }, as: :json

      expect(json_response.keys).to include('account', 'addresses', 'orders', 'marketing_consent', 'consent_records')
    end

    # The hook is documented as the way to complete a subject access response
    # with host-app data. The admin path is the one merchants actually use, so
    # skipping it there would silently omit exactly what it exists to add.
    describe 'the payload extension hook' do
      let(:handler) { ->(_workflow) { { loyalty: { points: 120 } } } }

      before { Spree.hooks.register('data_requests.fulfill.extend_payload', handler) }
      after { Spree.hooks.unregister('data_requests.fulfill.extend_payload', handler) }

      it 'runs on the admin export too' do
        get :export, params: { id: customer.prefixed_id }, as: :json

        expect(json_response.dig('loyalty', 'points')).to eq(120)
      end

      it 'still includes what Spree knows' do
        get :export, params: { id: customer.prefixed_id }, as: :json

        expect(json_response.dig('account', 'email')).to eq(customer.email)
      end
    end

    # Completing the customer's own request here would close it without ever
    # delivering their file: the queued job then refuses it as no longer
    # pending, and they wait for an email that never arrives.
    it 'leaves a request the customer already made alone' do
      pending_request = Spree::DataRequests::Create.call(
        store: store, customer: customer, kind: Spree::DataRequest::ACCESS
      ).value

      get :export, params: { id: customer.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(pending_request.reload).to be_pending
    end

    it 'leaves a record that the request was answered' do
      expect {
        get :export, params: { id: customer.prefixed_id }, as: :json
      }.to change { Spree::DataRequest.where(customer_id: customer.id).count }.by(1)
    end

    # The export carries the customer's order history, which is otherwise
    # gated on read_orders. Aggregating the two behind one key would hand
    # order data to a role that was never granted it.
    context 'when the caller may read customers but not orders' do
      # Overrides the shared JWT rather than setting a header: the shared
      # headers also carry a full-scope secret key, which outranks a JWT and
      # would authorize the request whatever the staffer's roles say.
      let(:admin_user) do
        create(:admin_user, :without_admin_role).tap do |user|
          create(:role_user, user: user,
                             role: create(:role, name: 'Support', permissions: %w[read_customers], resource: store))
        end
      end

      it 'refuses the export and says which permission is missing' do
        get :export, params: { id: customer.prefixed_id }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(json_response.dig('error', 'details', 'required_permission')).to eq('read_orders')
      end
    end

    # The response reaches past orders into saved cards, balances and gift
    # cards, each of which has its own key elsewhere in the API.
    context 'when the caller may read customers and orders but nothing else' do
      let(:admin_user) do
        create(:admin_user, :without_admin_role).tap do |user|
          create(:role_user, user: user,
                             role: create(:role, name: 'Orders', resource: store,
                                                 permissions: %w[read_customers read_orders]))
        end
      end

      it 'refuses the export and names the first permission it lacks' do
        get :export, params: { id: customer.prefixed_id }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(json_response.dig('error', 'details', 'required_permission')).to eq('read_payments')
      end
    end

    it 'records a staff marketing change as the staff member\'s, not the customer\'s' do
      patch :update, params: { id: customer.prefixed_id, accepts_email_marketing: true }, as: :json

      expect(customer.reload.email_marketing_consent_source).to eq(Spree::ConsentRecord::ADMIN)
    end

    it '404s for a customer that does not exist' do
      get :export, params: { id: 'cust_nonexistent' }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #anonymize' do
    it 'erases the customer' do
      post :anonymize, params: { id: customer.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(customer.reload.email).not_to eq('buyer@example.com')
      expect(customer.anonymized_at).to be_present
    end

    it 'reports the erasure in the response' do
      post :anonymize, params: { id: customer.prefixed_id }, as: :json

      expect(json_response['anonymized']).to be(true)
    end

    # The request log is what an Art. 30 enquiry reads, and the ordinary
    # merchant path — an email from someone who cannot sign in — was leaving
    # only an event behind.
    it 'records the request it answered' do
      expect {
        post :anonymize, params: { id: customer.prefixed_id }, as: :json
      }.to change { Spree::DataRequest.erasure.where(customer_id: customer.id).count }.by(1)
    end

    it 'marks that record completed' do
      post :anonymize, params: { id: customer.prefixed_id }, as: :json

      expect(Spree::DataRequest.erasure.where(customer_id: customer.id).last).to be_completed
    end

    it 'refuses a customer already erased' do
      post :anonymize, params: { id: customer.prefixed_id }, as: :json

      post :anonymize, params: { id: customer.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'keeps a completed order the customer placed' do
      order = create(:completed_order_with_totals, customer: customer, store: store)

      post :anonymize, params: { id: customer.prefixed_id }, as: :json

      expect(order.reload).to be_persisted
      expect(order.total).to be_positive
    end
  end
end
