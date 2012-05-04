require 'spec_helper'

describe Spree::UsersController do
  let(:admin_user) { create(:user) }
  let(:user) { create(:user) }

  before do
    sign_in user
  end

  context '#create' do
    it 'should create a new user' do
      post :create, { :user => { :email => 'foobar@example.com', :password => 'foobar123', :password_confirmation => 'foobar123' } }
      assigns[:user].new_record?.should be_false
    end

    context 'when an order exists in the session' do
      let(:order) { mock_model Spree::Order }
      before { controller.stub :current_order => order }

      it 'should assign the user to the order' do
        order.should_receive(:associate_user!)
        post :create, { :user => { :email => 'foobar@spreecommerce.com', :password => 'foobar123', :password_confirmation => 'foobar123' } }
      end
    end
  end

  context '#update' do
    context 'when updating own account' do
      it 'should perform update' do
        put :update, { :user => { :email => 'mynew@email-address.com' } }
        assigns[:user].email.should == 'mynew@email-address.com'
        response.should redirect_to(spree.account_url(:only_path => true))
      end
    end

    context 'when attempting to update other account' do
      it 'should not allow update' do
        put :update, { :user => create(:user) }, { :user => { :email => 'mynew@email-address.com' } }
        response.should redirect_to(spree.login_url(:only_path => true))
      end
    end
  end
end
