require 'spec_helper'

describe Spree::UserSessionsController do
  before do
    request.env["devise.mapping"] = Devise.mappings[:user]
  end

  context '#create' do
    context 'when current_order is associated with a guest user' do
      let(:user) { mock Spree::User }
      let(:order) { mock_model Spree::Order }

      before do
        controller.stub :current_user => user
        controller.stub :current_order => order
      end

      it 'should associate the order with the newly authenticated user' do
        order.should_receive(:associate_user!).with(user)
        spree_post :create, {}, { :order_id => 1 }
      end

      it 'should destroy the session token for guest_user' do
        order.stub(:associate_user!)
        spree_post :create, {}, { :order_id => 1, :guest_token => 'foo' }
        session[:guest_token].should be_nil
      end
    end
  end
end
