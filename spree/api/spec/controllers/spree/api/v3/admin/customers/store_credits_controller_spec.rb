require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Customers::StoreCreditsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:customer) { create(:user) }
  let(:category) { create(:store_credit_category) }
  let!(:store_credit) { create(:store_credit, user: customer, store: store, amount: 50.00, category: category) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns the customer store credits' do
      get :index, params: { customer_id: customer.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |sc| sc['id'] }).to include(store_credit.prefixed_id)
    end

    # Broken object-level authorization: the nested index must enforce the
    # caller's ability on the parent customer. A customer the caller can't view
    # is filtered out of the ability-scoped lookup, so it 404s rather than
    # leaking its existence as a 403.
    context 'with a limited-role admin that cannot read customers' do
      include_context 'API v3 Admin with custom permissions'

      let(:custom_permission_set) do
        Class.new(Spree::PermissionSets::Base) do
          def activate!
            can [:read, :admin], Spree::Product
          end
        end
      end

      it 'cannot read another customer\'s store credits' do
        get :index, params: { customer_id: customer.prefixed_id }, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # A role that can only VIEW customers must not be able to write to a
  # customer's nested collection. `set_parent` resolves the parent via the
  # write ability for write actions, so a view-only role can't reach the
  # customer to mutate it (404, not a leaky 403).
  describe 'write authorization with a read-only customer role' do
    include_context 'API v3 Admin with custom permissions'

    let(:custom_permission_set) do
      Class.new(Spree::PermissionSets::Base) do
        def activate!
          can [:read, :admin], Spree.user_class
          can :manage, Spree::StoreCredit
        end
      end
    end

    it 'allows reading the customer\'s store credits' do
      get :index, params: { customer_id: customer.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
    end

    it 'cannot create a store credit on a customer it can only view' do
      expect {
        post :create, params: {
          customer_id: customer.prefixed_id, amount: 10.0, currency: 'USD', category_id: category.id
        }, as: :json
      }.not_to change(customer.store_credits, :count)

      expect(response).to have_http_status(:not_found)
    end
  end

  # A secret API key authorizes purely on scopes (no CanCanCan): a read-only
  # `read_store_credits` key must be rejected on any write at the scope-check
  # layer, while `write_store_credits` succeeds.
  describe 'secret API key scope enforcement on writes' do
    let(:secret_api_key) { create(:api_key, :secret, store: store, scopes: [granted_scope]) }
    let(:headers) { { 'x-spree-api-key' => secret_api_key.plaintext_token } }

    let(:create_params) do
      { customer_id: customer.prefixed_id, amount: 10.0, currency: 'USD', category_id: category.id }
    end

    context 'with a key granting only read_store_credits' do
      let(:granted_scope) { 'read_store_credits' }

      it 'allows reading' do
        get :index, params: { customer_id: customer.prefixed_id }, as: :json

        expect(response).to have_http_status(:ok)
      end

      it 'rejects creating a store credit with 403' do
        expect {
          post :create, params: create_params, as: :json
        }.not_to change(customer.store_credits, :count)

        expect(response).to have_http_status(:forbidden)
        expect(json_response['error']['details']['required_scope']).to eq('write_store_credits')
      end
    end

    context 'with a key granting write_store_credits' do
      let(:granted_scope) { 'write_store_credits' }

      it 'allows creating a store credit' do
        expect {
          post :create, params: create_params, as: :json
        }.to change(customer.store_credits, :count).by(1)

        expect(response).to have_http_status(:created)
      end
    end
  end

  describe 'POST #create' do
    it 'creates a store credit and sets created_by' do
      expect {
        post :create, params: {
          customer_id: customer.prefixed_id,
          amount: 25.00,
          currency: 'USD',
          category_id: category.id,
          memo: 'Goodwill'
        }, as: :json
      }.to change(customer.store_credits, :count).by(1)

      expect(response).to have_http_status(:created)
      created = Spree::StoreCredit.find_by_prefix_id(json_response['id'])
      expect(created.created_by).to eq(admin_user)
      expect(created.amount).to eq(25.00)
      expect(created.memo).to eq('Goodwill')
    end
  end

  describe 'PATCH #update' do
    it 'updates memo' do
      patch :update, params: { customer_id: customer.prefixed_id, id: store_credit.prefixed_id, memo: 'Updated memo' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(store_credit.reload.memo).to eq('Updated memo')
    end

    context 'when store credit has been used' do
      before { store_credit.update_column(:amount_used, 10.00) }

      it 'rejects amount changes with 422' do
        patch :update, params: { customer_id: customer.prefixed_id, id: store_credit.prefixed_id, amount: 100.00 }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'allows memo changes' do
        patch :update, params: { customer_id: customer.prefixed_id, id: store_credit.prefixed_id, memo: 'Still ok' }, as: :json

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys an unused store credit' do
      delete :destroy, params: { customer_id: customer.prefixed_id, id: store_credit.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
    end

    context 'when store credit has been used' do
      before { store_credit.update_column(:amount_used, 10.00) }

      it 'returns 422' do
        delete :destroy, params: { customer_id: customer.prefixed_id, id: store_credit.prefixed_id }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
