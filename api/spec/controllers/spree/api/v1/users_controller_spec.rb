require 'spec_helper'

module Spree
  describe Api::V1::UsersController, type: :controller do
    render_views

    let(:user) { create(:user, spree_api_key: rand.to_s) }
    let(:stranger) { create(:user, email: 'stranger@example.com') }
    let(:attributes) { [:id, :email, :created_at, :updated_at] }

    context 'as a normal user' do
      it 'can get own details' do
        api_get :show, id: user.id, token: user.spree_api_key

        expect(json_response['email']).to eq user.email
      end

      it 'cannot get other users details' do
        api_get :show, id: stranger.id, token: user.spree_api_key

        assert_not_found!
      end

      it 'can learn how to create a new user' do
        api_get :new, token: user.spree_api_key
        expect(json_response['attributes']).to eq(attributes.map(&:to_s))
      end

      it 'can create a new user' do
        user_params = {
          email: 'new@example.com', password: 'spree123', password_confirmation: 'spree123'
        }

        api_post :create, user: user_params, token: user.spree_api_key
        expect(json_response['email']).to eq 'new@example.com'
      end

      # there's no validations on LegacyUser?
      xit 'cannot create a new user with invalid attributes' do
        api_post :create, user: {}, token: user.spree_api_key
        expect(response.status).to eq(422)
        expect(json_response['error']).to eq('Invalid resource. Please fix errors and try again.')
      end

      it 'can update own details' do
        country = create(:country)
        api_put :update, id: user.id, token: user.spree_api_key, user: {
          email: 'mine@example.com',
          bill_address_attributes: {
            first_name: 'First',
            last_name: 'Last',
            address1: '1 Test Rd',
            city: 'City',
            country_id: country.id,
            state_id: 1,
            zipcode: '55555',
            phone: '5555555555'
          },
          ship_address_attributes: {
            first_name: 'First',
            last_name: 'Last',
            address1: '1 Test Rd',
            city: 'City',
            country_id: country.id,
            state_id: 1,
            zipcode: '55555',
            phone: '5555555555'
          }
        }
        expect(json_response['email']).to eq 'mine@example.com'
        expect(json_response['bill_address']).not_to be_nil
        expect(json_response['ship_address']).not_to be_nil
      end

      it 'cannot update other users details' do
        api_put :update, id: stranger.id, token: user.spree_api_key, user: { email: 'mine@example.com' }
        assert_not_found!
      end

      it 'can delete itself' do
        api_delete :destroy, id: user.id, token: user.spree_api_key
        expect(response.status).to eq(204)
      end

      it 'cannot delete other user' do
        api_delete :destroy, id: stranger.id, token: user.spree_api_key
        assert_not_found!
      end

      it 'only gets own details on index' do
        create_list(:user, 2)
        api_get :index, token: user.spree_api_key

        expect(Spree.user_class.count).to eq 3
        expect(json_response['count']).to eq 1
        expect(json_response['users'].size).to eq 1
      end
    end

    context 'as an admin' do
      before { stub_authentication! }

      sign_in_as_admin!

      it 'gets all users' do
        allow(Spree::LegacyUser).to receive(:find_by).with(hash_including(:spree_api_key)) { current_api_user }

        create_list(:user, 2)

        api_get :index
        expect(Spree.user_class.count).to eq 2
        expect(json_response['count']).to eq 2
        expect(json_response['users'].size).to eq 2
      end

      context 'can query the results through' do
        let(:first_bill_address) { create(:bill_address, firstname: 'John', lastname: 'Snow') }
        let(:second_bill_address) { create(:bill_address, firstname: 'Michael', lastname: 'Michael') }

        let!(:first_user) { create(:user, bill_address: first_bill_address, email: 'actor@example.com') }
        let!(:second_user) { create(:user, bill_address: second_bill_address, email: 'singer@example.com') }

        before do
          allow(Spree::LegacyUser).to receive(:find_by).with(hash_including(:spree_api_key)) { current_api_user }
        end

        it 'existing bill_address firstname parameter' do
          api_get :index, q: {
            email_start: 'John',
            bill_address_firstname_start: 'John',
            bill_address_lastname_start: 'John',
            ship_address_firstname_start: 'John',
            ship_address_lastname_start: 'John'
          }

          expect(Spree.user_class.count).to eq 2
          expect(json_response['count']).to eq 1
          expect(json_response['users'].size).to eq 1
          expect(json_response['users'].first['email']).to eq first_user.email
        end

        it 'existing bill_address lastname parameter' do
          api_get :index, q: {
            email_start: 'Snow',
            bill_address_firstname_start: 'Snow',
            bill_address_lastname_start: 'Snow',
            ship_address_firstname_start: 'Snow',
            ship_address_lastname_start: 'Snow'
          }

          expect(Spree.user_class.count).to eq 2
          expect(json_response['count']).to eq 1
          expect(json_response['users'].size).to eq 1
          expect(json_response['users'].first['email']).to eq first_user.email
        end

        it 'existing bill_address firstname and lastname parameter' do
          api_get :index, q: { 
            email_start: 'Michael',
            bill_address_firstname_start: 'Michael',
            bill_address_lastname_start: 'Michael',
            ship_address_firstname_start: 'Michael',
            ship_address_lastname_start: 'Michael'
          }

          expect(Spree.user_class.count).to eq 2
          expect(json_response['count']).to eq 1
          expect(json_response['users'].size).to eq 1
          expect(json_response['users'].first['email']).to eq second_user.email
        end

        it 'non-existenting ship_address firstname parameter' do
          api_get :index, q: { 
            email_start: 'Result',
            bill_address_firstname_start: 'Result',
            bill_address_lastname_start: 'Result',
            ship_address_firstname_start: 'Result',
            ship_address_lastname_start: 'Result'
          }

          expect(Spree.user_class.count).to eq 2
          expect(json_response['count']).to eq 0
          expect(json_response['users'].size).to eq 0
        end

        it 'existing email paramter' do
          api_get :index, q: {
            email_start: 'actor',
            bill_address_firstname_start: 'actor',
            bill_address_lastname_start: 'actor',
            ship_address_firstname_start: 'actor',
            ship_address_lastname_start: 'actor'
          }

          expect(Spree.user_class.count).to eq 2
          expect(json_response['count']).to eq(1)
          expect(json_response['users'].first['email']).to eq first_user.email
        end
      end

      it 'can control the page size through a parameter' do
        create_list(:user, 2)
        api_get :index, per_page: 1
        expect(json_response['count']).to eq(1)
        expect(json_response['current_page']).to eq(1)
        expect(json_response['pages']).to eq(2)
      end

      it 'can create' do
        api_post :create, user: { email: 'new@example.com', password: 'spree123', password_confirmation: 'spree123' }
        expect(json_response).to have_attributes(attributes)
        expect(response.status).to eq(201)
      end

      it 'can destroy user without orders' do
        user.orders.destroy_all
        api_delete :destroy, id: user.id
        expect(response.status).to eq(204)
      end

      it 'cannot destroy user with orders' do
        create(:completed_order_with_totals, user: user)
        api_delete :destroy, id: user.id
        expect(json_response['exception']).to eq 'Spree::Core::DestroyWithOrdersError'
        expect(response.status).to eq(422)
      end
    end
  end
end
