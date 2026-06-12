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
    # caller's ability on the parent customer, not just resolve it.
    context 'with a limited-role admin that cannot read customers' do
      include_context 'API v3 Admin with custom permissions'

      let(:custom_permission_set) do
        Class.new(Spree::PermissionSets::Base) do
          def activate!
            can [:read, :admin], Spree::Product
          end
        end
      end

      it 'forbids reading another customer\'s store credits' do
        get :index, params: { customer_id: customer.prefixed_id }, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # A role that can only VIEW customers must not be able to write to a
  # customer's nested collection — set_parent requires :update for writes.
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

    it 'forbids creating a store credit on a customer it can only view' do
      expect {
        post :create, params: {
          customer_id: customer.prefixed_id, amount: 10.0, currency: 'USD', category_id: category.id
        }, as: :json
      }.not_to change(customer.store_credits, :count)

      expect(response).to have_http_status(:forbidden)
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
