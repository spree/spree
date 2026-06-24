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

    context 'with customer_group_ids' do
      let(:vip) { create(:customer_group, store: store, name: 'VIPs') }
      let(:wholesale) { create(:customer_group, store: store, name: 'Wholesale') }

      it 'replaces group membership using prefixed ids' do
        customer.customer_groups << vip

        patch :update, params: {
          id: customer.prefixed_id, customer_group_ids: [wholesale.prefixed_id]
        }, as: :json

        expect(response).to have_http_status(:ok)
        expect(customer.reload.customer_groups).to contain_exactly(wholesale)
        expect(json_response['customer_group_ids']).to contain_exactly(wholesale.prefixed_id)
      end

      it 'clears membership with an empty array' do
        customer.customer_groups << vip

        patch :update, params: { id: customer.prefixed_id, customer_group_ids: [] }, as: :json

        expect(response).to have_http_status(:ok)
        expect(customer.reload.customer_groups).to be_empty
      end
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

  describe 'POST #bulk_add_to_groups' do
    let(:alice) { create(:user, email: 'alice@example.com') }
    let(:bob) { create(:user, email: 'bob@example.com') }
    let(:vip) { create(:customer_group, store: store, name: 'VIPs') }
    let(:wholesale) { create(:customer_group, store: store, name: 'Wholesale') }

    it 'adds the listed customers to every listed group' do
      post :bulk_add_to_groups, params: {
        ids: [alice.prefixed_id, bob.prefixed_id],
        customer_group_ids: [vip.prefixed_id, wholesale.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(vip.reload.customers).to match_array([alice, bob])
      expect(wholesale.reload.customers).to match_array([alice, bob])
      expect(json_response).to eq('customer_count' => 2, 'customer_group_count' => 2)
    end

    it 'is idempotent — re-adding existing members is a no-op' do
      vip.customers << alice

      post :bulk_add_to_groups, params: {
        ids: [alice.prefixed_id], customer_group_ids: [vip.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(vip.reload.customers.size).to eq(1)
    end

    it 'ignores customer groups from other stores' do
      other_group = create(:customer_group, store: create(:store))

      post :bulk_add_to_groups, params: {
        ids: [alice.prefixed_id], customer_group_ids: [other_group.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(other_group.reload.customers).to be_empty
      expect(json_response['customer_group_count']).to eq(0)
    end
  end

  describe 'POST #bulk_remove_from_groups' do
    let(:alice) { create(:user, email: 'alice@example.com') }
    let(:bob) { create(:user, email: 'bob@example.com') }
    let(:vip) { create(:customer_group, store: store, name: 'VIPs') }

    before { vip.customers << [alice, bob] }

    it 'removes the listed customers from every listed group' do
      post :bulk_remove_from_groups, params: {
        ids: [alice.prefixed_id], customer_group_ids: [vip.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(vip.reload.customers).to eq([bob])
    end

    it 'is a no-op for non-members' do
      stranger = create(:user)

      post :bulk_remove_from_groups, params: {
        ids: [stranger.prefixed_id], customer_group_ids: [vip.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(vip.reload.customers).to match_array([alice, bob])
    end
  end

  describe 'POST #bulk_add_tags' do
    let!(:alice) { create(:user, email: 'alice@example.com').tap { |u| store.add_user(u) } }
    let!(:bob) { create(:user, email: 'bob@example.com').tap { |u| store.add_user(u) } }

    it 'adds the listed tags to every listed customer' do
      post :bulk_add_tags, params: {
        ids: [alice.prefixed_id, bob.prefixed_id],
        tags: %w[vip newsletter]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('customer_count' => 2, 'tag_count' => 2)
      expect(alice.reload.tag_list).to include('vip', 'newsletter')
      expect(bob.reload.tag_list).to include('vip', 'newsletter')
    end

    it 'is idempotent — re-adding the same tag does not duplicate it' do
      alice.tag_list.add('vip')
      alice.save!

      post :bulk_add_tags, params: {
        ids: [alice.prefixed_id], tags: ['vip']
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(alice.reload.tag_list.count { |t| t == 'vip' }).to eq(1)
    end

    # Users aren't store-scoped (`Spree.user_class.for_store` is a no-op by
    # design — admins are users too), so cross-store filtering happens at
    # the ability layer, not the relation. Bulk endpoints follow suit and
    # apply tags to any user the admin can update.
    it 'silently drops unreachable IDs' do
      post :bulk_add_tags, params: {
        ids: ['cus_nonexistent'], tags: ['vip']
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['customer_count']).to eq(0)
    end

    it 'is a no-op when tags is empty' do
      post :bulk_add_tags, params: {
        ids: [alice.prefixed_id], tags: []
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('customer_count' => 1, 'tag_count' => 0)
      expect(alice.reload.tag_list).to be_empty
    end
  end

  describe 'POST #bulk_remove_tags' do
    let!(:alice) do
      create(:user, email: 'alice@example.com', tag_list: ['vip', 'newsletter']).tap { |u| store.add_user(u) }
    end
    let!(:bob) do
      create(:user, email: 'bob@example.com', tag_list: ['vip']).tap { |u| store.add_user(u) }
    end

    it 'removes the listed tags from every listed customer' do
      post :bulk_remove_tags, params: {
        ids: [alice.prefixed_id, bob.prefixed_id],
        tags: ['vip']
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('customer_count' => 2, 'tag_count' => 1)
      expect(alice.reload.tag_list).not_to include('vip')
      expect(alice.reload.tag_list).to include('newsletter')
      expect(bob.reload.tag_list).not_to include('vip')
    end

    it 'is a no-op for customers without the tag' do
      stranger = create(:user).tap { |u| store.add_user(u) }

      post :bulk_remove_tags, params: {
        ids: [stranger.prefixed_id], tags: ['vip']
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(stranger.reload.tag_list).to be_empty
    end
  end
end
