require 'spec_helper'

RSpec.describe Spree::Admin::CustomerGroupUsersController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }
  let(:customer_group) { create(:customer_group, store: store) }

  describe 'GET #index' do
    subject(:index) { get :index, params: { customer_group_id: customer_group.id } }

    let(:user1) { create(:user) }
    let(:user2) { create(:user) }

    before do
      customer_group.add_customers([user1.id, user2.id])
    end

    it 'returns success' do
      index
      expect(response).to have_http_status(:ok)
    end

    it 'renders the list of users in the group' do
      index

      expect(response).to render_template(:index)
      expect(assigns[:collection]).to include(user1, user2)
    end

    it 'does not include users not in the group' do
      other_user = create(:user)
      index

      expect(assigns[:collection]).not_to include(other_user)
    end
  end

  describe 'GET #bulk_new' do
    subject(:bulk_new) { get :bulk_new, params: { customer_group_id: customer_group.id } }

    it 'returns success' do
      bulk_new
      expect(response).to have_http_status(:ok)
    end

    it 'renders the bulk_new template' do
      bulk_new
      expect(response).to render_template(:bulk_new)
    end
  end

  describe 'POST #create' do
    subject(:create_membership) { post :create, params: { customer_group_id: customer_group.id, user_ids: user_ids } }

    let(:user1) { create(:user) }
    let(:user2) { create(:user) }
    let(:user_ids) { [user1.id, user2.id] }

    it 'redirects to customer group page' do
      create_membership
      expect(response).to redirect_to(spree.admin_customer_group_path(customer_group))
    end

    it 'adds users to the customer group' do
      expect { create_membership }.to change(Spree::CustomerGroupUser, :count).by(2)

      expect(customer_group.users).to include(user1, user2)
    end

    it 'sets success flash message' do
      create_membership
      expect(flash[:success]).to eq(Spree.t(:customers_added_to_group, count: 2))
    end

    context 'when no users are selected' do
      let(:user_ids) { [] }

      it 'does not create any memberships and shows error' do
        expect { create_membership }.not_to change(Spree::CustomerGroupUser, :count)

        expect(flash[:error]).to eq(Spree.t(:no_users_selected))
      end
    end

    context 'when user is already in the group' do
      before { customer_group.add_customers([user1.id]) }

      it 'only adds new users' do
        expect { create_membership }.to change(Spree::CustomerGroupUser, :count).by(1)

        expect(customer_group.users.count).to eq(2)
      end
    end
  end

  describe 'DELETE #destroy' do
    subject(:destroy_membership) { delete :destroy, params: { customer_group_id: customer_group.id, id: user.id } }

    let(:user) { create(:user) }

    before do
      customer_group.add_customers([user.id])
    end

    it 'redirects to customer group page' do
      destroy_membership
      expect(response).to redirect_to(spree.admin_customer_group_path(customer_group))
    end

    it 'removes the user from the customer group' do
      expect { destroy_membership }.to change(Spree::CustomerGroupUser, :count).by(-1)

      expect(customer_group.reload.users).not_to include(user)
    end

    it 'sets success flash message' do
      destroy_membership
      expect(flash[:success]).to eq(Spree.t(:customer_removed_from_group))
    end

    context 'when user is not in the group' do
      let(:other_user) { create(:user) }

      it 'sets error flash message' do
        delete :destroy, params: { customer_group_id: customer_group.id, id: other_user.id }
        expect(flash[:error]).to eq(Spree.t(:customer_could_not_be_removed_from_group))
      end
    end
  end

  describe 'POST #bulk_create' do
    subject(:bulk_create) { post :bulk_create, params: { customer_group_id: customer_group.id, ids: user_ids }, format: :turbo_stream }

    let(:user1) { create(:user) }
    let(:user2) { create(:user) }
    let(:user_ids) { [user1.id, user2.id] }

    it 'returns success' do
      bulk_create
      expect(response).to have_http_status(:ok)
    end

    it 'adds selected users to the customer group' do
      expect { bulk_create }.to change(Spree::CustomerGroupUser, :count).by(2)

      expect(customer_group.users).to include(user1, user2)
    end

    it 'sets success flash message' do
      bulk_create
      expect(flash[:success]).to eq(Spree.t(:customers_added_to_group, count: 2))
    end

    context 'when user is already in the group' do
      before { customer_group.add_customers([user1.id]) }

      it 'only adds new users' do
        expect { bulk_create }.to change(Spree::CustomerGroupUser, :count).by(1)

        expect(customer_group.users.count).to eq(2)
      end
    end
  end

  describe 'DELETE #bulk_destroy' do
    subject(:bulk_destroy) { delete :bulk_destroy, params: { customer_group_id: customer_group.id, ids: user_ids }, format: :turbo_stream }

    let(:user1) { create(:user) }
    let(:user2) { create(:user) }
    let(:user3) { create(:user) }
    let(:user_ids) { [user1.id, user2.id] }

    before do
      customer_group.add_customers([user1.id, user2.id, user3.id])
    end

    it 'returns success' do
      bulk_destroy
      expect(response).to have_http_status(:ok)
    end

    it 'removes selected users from the customer group' do
      expect { bulk_destroy }.to change(Spree::CustomerGroupUser, :count).by(-2)

      customer_group.reload
      expect(customer_group.users).not_to include(user1, user2)
      expect(customer_group.users).to include(user3)
    end

    it 'sets success flash message' do
      bulk_destroy
      expect(flash[:success]).to eq(Spree.t(:customers_removed_from_group, count: 2))
    end

    context 'when no users are selected' do
      let(:user_ids) { [] }

      it 'sets error flash message' do
        bulk_destroy
        expect(flash[:error]).to eq(Spree.t(:no_users_selected))
      end
    end
  end
end
