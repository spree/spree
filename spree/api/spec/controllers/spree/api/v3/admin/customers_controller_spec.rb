require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CustomersController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:customer) { create(:user) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns customers' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].map { |c| c['id'] }).to include(customer.prefixed_id)
    end

    context 'with ransack search' do
      let!(:matching) { create(:user, email: 'jane@example.com', first_name: 'Jane') }

      it 'filters by search scope' do
        get :index, params: { q: { search: 'jane' } }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].map { |c| c['id'] }).to include(matching.prefixed_id)
      end

      it 'filters by email_cont' do
        get :index, params: { q: { email_cont: 'jane@example.com' } }, as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response['data'].map { |c| c['id'] }).to contain_exactly(matching.prefixed_id)
      end
    end
  end

  describe 'GET #show' do
    it 'returns the customer with computed stats' do
      get :show, params: { id: customer.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(customer.prefixed_id)
      expect(json_response['email']).to eq(customer.email)
      expect(json_response).to have_key('orders_count')
      expect(json_response).to have_key('total_spent')
      expect(json_response).to have_key('tags')
    end

    it 'returns 404 for unknown id' do
      get :show, params: { id: 'cus_unknown' }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    let(:create_params) do
      {
        email: 'new-customer@example.com',
        first_name: 'Sam',
        last_name: 'Johnson',
        phone: '+15555550199',
        accepts_email_marketing: true,
        tags: ['wholesale', 'priority']
      }
    end

    it 'creates a customer' do
      expect { post :create, params: create_params, as: :json }.to change(Spree.user_class, :count).by(1)

      expect(response).to have_http_status(:created)
      created = Spree.user_class.find_by_prefix_id(json_response['id'])
      expect(created.email).to eq('new-customer@example.com')
      expect(created.first_name).to eq('Sam')
      expect(created.tag_list).to contain_exactly('wholesale', 'priority')
    end

    context 'with invalid params' do
      it 'returns validation errors for missing email' do
        post :create, params: { first_name: 'NoEmail' }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    # Admin-created customers don't pick a password upfront — the merchant
    # adds the profile and the customer claims the account via a separate
    # password-reset flow. The host app's `Spree::User` is Devise-
    # validatable; `Spree::UserMethods` exposes `skip_password_validation`
    # so the admin controller can opt out of the presence check on create.
    # The Store API registration path stays untouched (see store
    # customers_controller spec).
    context 'without password' do
      let(:no_password_params) { { email: 'no-password@example.com', first_name: 'Pat' } }

      it 'creates the customer' do
        expect { post :create, params: no_password_params, as: :json }.
          to change(Spree.user_class, :count).by(1)

        expect(response).to have_http_status(:created)
      end

      it 'leaves the customer with no usable credential' do
        post :create, params: no_password_params, as: :json

        created = Spree.user_class.find_by_prefix_id(json_response['id'])
        expect(created.encrypted_password).to be_blank
      end
    end
  end

  describe 'PATCH #update' do
    it 'updates the customer' do
      patch :update, params: { id: customer.prefixed_id, first_name: 'Updated' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(customer.reload.first_name).to eq('Updated')
    end

    it 'replaces tags (not append)' do
      customer.update!(tag_list: ['old-tag'])

      patch :update, params: { id: customer.prefixed_id, tags: ['new-tag'] }, as: :json

      expect(response).to have_http_status(:ok)
      expect(customer.reload.tag_list).to contain_exactly('new-tag')
    end

    # PATCH without a password must not blank an existing credential. Devise's
    # `password_required?` already skips presence on persisted records when
    # password is nil, so this is the regression guard for that contract —
    # ensures a profile-only edit doesn't accidentally invalidate the
    # customer's ability to log in.
    context 'without password' do
      it 'updates profile fields without touching the existing credential' do
        original_digest = customer.encrypted_password
        expect(original_digest).to be_present

        patch :update, params: { id: customer.prefixed_id, first_name: 'Updated' }, as: :json

        expect(response).to have_http_status(:ok)
        expect(customer.reload.first_name).to eq('Updated')
        expect(customer.encrypted_password).to eq(original_digest)
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys a customer with no orders' do
      target = create(:user)

      expect {
        delete :destroy, params: { id: target.prefixed_id }, as: :json
      }.to change(Spree.user_class, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    context 'when customer has completed orders' do
      let(:target) { create(:user) }
      before { create(:completed_order_with_totals, user: target, store: store) }

      it 'returns 422 with error' do
        delete :destroy, params: { id: target.prefixed_id }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
