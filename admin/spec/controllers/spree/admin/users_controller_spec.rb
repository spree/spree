require 'spec_helper'

RSpec.describe Spree::Admin::UsersController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }

  describe 'GET #index' do
    let!(:user_1) { create(:user, first_name: 'John', last_name: 'Doe', email: 'john.doe@example.com') }
    let!(:user_2) { create(:user, tag_list: ['some tag']) }
    let!(:user_3) { create(:user, accepts_email_marketing: true) }

    let!(:user_1_orders) { create_list(:completed_order_with_totals, 3, user: user_1, completed_at: 1.day.ago) }
    let!(:user_2_orders) { create_list(:completed_order_with_totals, 1, user: user_2, completed_at: 1.day.ago) }

    before do
      user_1_orders[0].update_column(:total, 300)
      user_1_orders[1].update_column(:total, 200)
      user_1_orders[2].update_column(:total, 500)

      user_2_orders[0].update_column(:total, 20)
    end

    it 'renders the list of users' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:index)

      expect(assigns(:collection).to_a).to include(user_1, user_2, user_3)
    end

    it 'returns subscribers' do
      get :index, params: { q: { accepts_email_marketing_eq: 'true' } }
      expect(assigns(:collection).to_a).to eq([user_3])
    end

    it 'returns customer based on tags' do
      get :index, params: { q: { tags_name_in: ['some tag'] } }
      expect(assigns(:collection).to_a).to eq([user_2])
    end

    describe 'multi_search' do
      subject { get :index, params: { q: { multi_search: multi_search_param } } }

      context 'when searching by email' do
        let(:multi_search_param) { 'john.doe@example.com' }

        it 'returns users based on an email' do
          subject
          expect(assigns(:collection).to_a).to eq([user_1])
        end
      end

      context 'when searching by the first name' do
        let(:multi_search_param) { 'john' }

        it 'returns users based on the first name' do
          subject
          expect(assigns(:collection).to_a).to eq([user_1])
        end
      end

      context 'when searching by the last name' do
        let(:multi_search_param) { 'doe' }

        it 'returns users based on the last name' do
          subject
          expect(assigns(:collection).to_a).to eq([user_1])
        end
      end

      context 'when searching by the full name' do
        let(:multi_search_param) { 'joh do' }

        it 'returns users based on the full name' do
          subject
          expect(assigns(:collection).to_a).to eq([user_1])
        end
      end

      context 'when the user is not found' do
        let(:multisearch_param) { 'mary' }

        it 'returns an empty list' do
          expect(assigns(:collection).to_a).to eq([])
        end
      end
    end

    context 'search by country name' do
      let!(:address) { create(:address, user: user_1) }
      let!(:other_address) { create(:address, user: user_1) }

      it 'should only give distinct user when searched with country name' do
        get :index, params: { q: { addresses_country_name_eq: address.country.name.to_s } }

        expect(assigns(:collection).to_a).to eq([user_1])
      end
    end
  end

  describe 'GET #show' do
    let(:user) { create(:user) }
    let!(:order) { create(:completed_order_with_totals, user: user) }

    it 'renders the user page with last order data' do
      get :show, params: { id: user.id }

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:show)

      expect(assigns(:last_order)).to eq(order)
      expect(assigns(:last_order_line_items)).to eq(order.line_items)
    end
  end

  describe 'GET #new' do
    it 'renders the new user form' do
      get :new

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:new)
    end
  end

  describe 'GET #edit' do
    let(:user) { create(:user) }

    it 'renders the edit user form' do
      get :edit, params: { id: user.id }

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:edit)
    end
  end

  describe 'POST #create' do
    it 'creates a new user' do
      post :create, params: { user: { email: 'test@example.com' } }
      expect(response).to redirect_to(spree.admin_user_path(assigns(:user)))
    end
  end

  describe 'PUT #update' do
    context 'when skipping tag params' do
      let!(:user) { create(:user, tag_list: ['Tag 1']) }

      it 'removes tags successfully' do
        put :update, params: { id: user.id, user: { last_name: 'Test' } }

        expect(user.reload.tag_list).to be_empty
        expect(user.reload.last_name).to eq('Test')

        expect(response).to redirect_to(spree.admin_user_path(user))
      end
    end
  end

  describe 'GET #bulk_modal' do
    it 'renders the bulk modal' do
      get :bulk_modal, params: { kind: 'add_tags' }

      expect(response).to have_http_status(:ok)
      expect(assigns[:title]).to eq(Spree.t('admin.bulk_ops.users.title.add_tags'))
      expect(assigns[:body]).to eq(Spree.t('admin.bulk_ops.users.body.add_tags'))
    end

    it 'returns not found for unknown kind' do
      get :bulk_modal, params: { kind: 'unknown' }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #bulk_add_tags' do
    let(:users) { create_list(:user, 3) }
    let(:tags) { ['tag1', 'tag2'] }

    it 'adds tags to users' do
      post :bulk_add_tags, params: { ids: users.pluck(:id), tags: tags }, format: :turbo_stream

      users.each do |user|
        expect(user.reload.tag_list).to contain_exactly(*tags)
      end
    end
  end

  describe 'POST #bulk_remove_tags' do
    let(:users) { create_list(:user, 3, tag_list: ['tag1', 'tag2']) }
    let(:tags) { ['tag1', 'tag2'] }

    it 'removes tags from users' do
      users.each { |user| user.update(tag_list: tags) }
      post :bulk_remove_tags, params: { ids: users.map(&:id), tags: tags }, format: :turbo_stream

      users.each do |user|
        expect(user.reload.tag_list).to eq([])
      end
    end
  end

  describe 'GET #select_options' do
    let!(:user_1) { create(:user, email: 'alice@example.com') }
    let!(:user_2) { create(:user, email: 'bob@example.com') }
    let!(:user_3) { create(:user, email: 'alice.smith@example.com') }

    it 'returns users matching the search query as JSON' do
      get :select_options, params: { q: 'alice' }, format: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json.size).to eq(2)
      expect(json.map { |u| u['name'] }).to contain_exactly('alice@example.com', 'alice.smith@example.com')
    end

    it 'returns users with id and name (email) attributes' do
      get :select_options, params: { q: 'bob' }, format: :json

      json = JSON.parse(response.body)

      expect(json.size).to eq(1)
      expect(json.first).to eq({ 'id' => user_2.id, 'name' => 'bob@example.com' })
    end

    it 'returns empty array when no users match' do
      get :select_options, params: { q: 'nonexistent' }, format: :json

      json = JSON.parse(response.body)

      expect(json).to eq([])
    end

    it 'limits results to 50 users' do
      55.times { |i| create(:user, email: "test#{i}@example.com") }

      get :select_options, params: { q: 'test' }, format: :json

      json = JSON.parse(response.body)

      expect(json.size).to eq(50)
    end

    it 'orders results by email' do
      get :select_options, params: { q: 'example.com' }, format: :json

      json = JSON.parse(response.body)
      emails = json.map { |u| u['name'] }

      expect(emails.size).to be > 1
    end

    context 'with hash search params' do
      it 'accepts ransack-style hash params' do
        get :select_options, params: { q: { email_cont: 'bob' } }, format: :json

        json = JSON.parse(response.body)

        expect(json.size).to eq(1)
        expect(json.first['name']).to eq('bob@example.com')
      end
    end
  end
end
