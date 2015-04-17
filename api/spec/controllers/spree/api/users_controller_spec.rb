require 'spec_helper'

module Spree
  describe Api::UsersController, :type => :controller do
    render_views

    let(:user) { create(:user, spree_api_key: rand.to_s) }
    let(:stranger) { create(:user, :email => 'stranger@example.com') }
    let(:attributes) { [:id, :email, :created_at, :updated_at] }

    context "as a normal user" do
      it "can get own details" do
        api_get :show, id: user.id, token: user.spree_api_key

        expect(json_response['email']).to eq user.email
      end

      it "cannot get other users details" do
        api_get :show, id: stranger.id, token: user.spree_api_key

        assert_not_found!
      end

      it "can learn how to create a new user" do
        api_get :new, token: user.spree_api_key
        expect(json_response["attributes"]).to eq(attributes.map(&:to_s))
      end

      it "can create a new user" do
        user_params = {
          :email => 'new@example.com', :password => 'spree123', :password_confirmation => 'spree123'
        }

        api_post :create, :user => user_params, token: user.spree_api_key
        expect(json_response['email']).to eq 'new@example.com'
      end

      # there's no validations on LegacyUser?
      xit "cannot create a new user with invalid attributes" do
        api_post :create, :user => {}, token: user.spree_api_key
        expect(response.status).to eq(422)
        expect(json_response["error"]).to eq("Invalid resource. Please fix errors and try again.")
        errors = json_response["errors"]
      end

      it "can update own details" do
        country = create(:country)
        api_put :update, id: user.id, token: user.spree_api_key, user: {
          email: "mine@example.com",
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
        expect(json_response['bill_address']).to_not be_nil
        expect(json_response['ship_address']).to_not be_nil
      end

      it "cannot update other users details" do
        api_put :update, id: stranger.id, token: user.spree_api_key, user: { :email => "mine@example.com" }
        assert_not_found!
      end

      it "can delete itself" do
        api_delete :destroy, id: user.id, token: user.spree_api_key
        expect(response.status).to eq(204)
      end

      it "cannot delete other user" do
        api_delete :destroy, id: stranger.id, token: user.spree_api_key
        assert_not_found!
      end

      it "should only get own details on index" do
        2.times { create(:user) }
        api_get :index, token: user.spree_api_key

        expect(Spree.user_class.count).to eq 3
        expect(json_response['count']).to eq 1
        expect(json_response['users'].size).to eq 1
      end
    end

    context "as an admin" do
      before { stub_authentication! }

      sign_in_as_admin!

      it "gets all users" do
        allow(Spree::LegacyUser).to receive(:find_by).with(hash_including(:spree_api_key)) { current_api_user }

        2.times { create(:user) }

        api_get :index
        expect(Spree.user_class.count).to eq 2
        expect(json_response['count']).to eq 2
        expect(json_response['users'].size).to eq 2
      end

      it 'can control the page size through a parameter' do
        2.times { create(:user) }
        api_get :index, :per_page => 1
        expect(json_response['count']).to eq(1)
        expect(json_response['current_page']).to eq(1)
        expect(json_response['pages']).to eq(2)
      end

      it 'can query the results through a paramter' do
        expected_result = create(:user, :email => 'brian@spreecommerce.com')
        api_get :index, :q => { :email_cont => 'brian' }
        expect(json_response['count']).to eq(1)
        expect(json_response['users'].first['email']).to eq expected_result.email
      end

      it "can create" do
        api_post :create, :user => { :email => "new@example.com", :password => 'spree123', :password_confirmation => 'spree123' }
        expect(json_response).to have_attributes(attributes)
        expect(response.status).to eq(201)
      end

      it "can destroy user without orders" do
        user.orders.destroy_all
        api_delete :destroy, :id => user.id
        expect(response.status).to eq(204)
      end

      it "cannot destroy user with orders" do
        create(:completed_order_with_totals, :user => user)
        api_delete :destroy, :id => user.id
        expect(json_response["exception"]).to eq "Spree::Core::DestroyWithOrdersError"
        expect(response.status).to eq(422)
      end

    end
  end
end
