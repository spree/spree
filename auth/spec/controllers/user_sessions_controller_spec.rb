require 'spec_helper'

describe Spree::UserSessionsController do
  before do
    request.env['devise.mapping'] = Devise.mappings[:user]
  end

  context '#create' do
    context 'when current_order is associated with a guest user' do
      let(:guest_user) { mock Spree::User }
      let(:user) { mock Spree::User }
      let(:order) { mock_model Spree::Order, :user => guest_user}

      before do
        controller.stub :current_user => user
        controller.stub :current_order => order
      end

      context 'when current_user has incompleted order' do
        let(:user_order) { mock_model Spree::Order, :user => user}

        before do
          user.stub(:incompleted_orders).and_return([user_order])
        end

        it 'should merge the order' do
          user_order.should_receive(:merge!).with(order)
          post :create
        end

        it 'should destroy the session token for guest_user' do
          user_order.stub(:merge!)
          post :create, {}, { :order_id => 1, :guest_token => 'foo' }
          session[:guest_token].should be_nil
        end
      end

      context 'when current_user has no incompleted order' do
        before do
          user.stub(:incompleted_orders).and_return([])
        end

        it 'should associate the order with the newly authenticated user' do
          order.should_receive(:associate_user!).with(user)
          post :create, {}, { :order_id => 1 }
        end

        it 'should destroy the session token for guest_user' do
          order.stub(:associate_user!)
          post :create, {}, { :order_id => 1, :guest_token => 'foo' }
          session[:guest_token].should be_nil
        end
      end
    end
  end
end
