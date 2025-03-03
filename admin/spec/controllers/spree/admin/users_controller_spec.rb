require 'spec_helper'

RSpec.describe Spree::Admin::UsersController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { Spree::Store.default }

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

      expect(assigns(:collection).to_a).to contain_exactly(user_1, user_2, user_3)
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

    context 'csv' do
      let!(:country) { create(:country) }
      let!(:state) { create(:state, country: country) }
      let!(:address) { create(:address, user: user_1) }

      before do
        user_1.tag_list = ['Tag 1', 'Tag 2']
        user_1.save!
      end

      it 'returns a csv file' do
        get :index, params: { format: 'csv', q: { first_name_eq: user_1.first_name } }

        expect(response.headers['Content-Type']).to eq 'text/csv; charset=utf-8'
        expect(response.body.split("\n").count).to eq(2)

        user_csv_line = response.body.split("\n").last

        expect(user_csv_line).to eq(
          [
            user_1.first_name,
            user_1.last_name,
            user_1.email,
            user_1.accepts_email_marketing ? 'Yes' : 'No',
            user_1.address&.company,
            user_1.address&.address1,
            user_1.address&.address2,
            user_1.address&.city,
            user_1.address&.state_text,
            user_1.address&.state_abbr,
            user_1.address&.country&.name,
            user_1.address&.country&.iso,
            user_1.address&.zipcode,
            user_1.phone,
            user_1.amount_spent_in('USD').to_s,
            user_1.completed_orders.count.to_s,
            "\"#{user_1.tag_list.join(', ')}\"",
          ].join(',')
        )
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
      expect(response).to render_template(:bulk_modal)

      expect(assigns[:title]).to eq(Spree.t('admin.bulk_ops.users.title.add_tags'))
      expect(assigns[:body]).to eq(Spree.t('admin.bulk_ops.users.body.add_tags'))
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
end
