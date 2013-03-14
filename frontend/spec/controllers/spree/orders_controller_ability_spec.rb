require 'spec_helper'

module Spree
  describe OrdersController do
    ORDER_TOKEN = 'ORDER_TOKEN'

    let(:user) { create(:user) }
    let(:guest_user) { create(:user) }
    let(:order) { Spree::Order.new }

    it 'should understand order routes with token' do
      spree.token_order_path('R123456', 'ABCDEF').should == '/orders/R123456/token/ABCDEF'
    end

    context 'when no order exists in the session' do
      before { Spree::Order.stub :new => order }

      context '#populate' do
        context 'when not authenticated' do
          context 'when there is an order token' do
            before { order.stub :token => ORDER_TOKEN }

            it 'should store the token in the session' do
              spree_post :populate
              session[:access_token].should == ORDER_TOKEN
            end

            it 'should replace any previous access tokens' do
              session[:access_token] = 'OLD_TOKEN'
              spree_post :populate
              session[:access_token].should == ORDER_TOKEN
            end
          end
        end
      end
    end

    context 'when an order exists in the session' do
      let(:token) { 'some_token' }
      let(:specified_order) { create(:order) }

      before do
        controller.stub :current_order => order
        controller.stub :spree_current_user => user
      end

      context '#populate' do
        it 'should check if user is authorized for :edit' do
          controller.should_receive(:authorize!).with(:edit, order, token)
          spree_post :populate, :token => token
        end
        it "should check against the specified order" do
          controller.should_receive(:authorize!).with(:edit, specified_order, token)
          spree_post :populate, :id => specified_order.number, :token => token
        end
      end

      context '#edit' do
        it 'should check if user is authorized for :edit' do
          controller.should_receive(:authorize!).with(:edit, order, token)
          spree_get :edit, :token => token
        end
        it "should check against the specified order" do
          controller.should_receive(:authorize!).with(:edit, specified_order, token)
          spree_get :edit, :id => specified_order.number, :token => token
        end
      end

      context '#update' do
        it 'should check if user is authorized for :edit' do
          order.stub :update_attributes
          controller.should_receive(:authorize!).with(:edit, order, token)
          spree_post :update, :order => { :email => "foo@bar.com" }, :token => token
        end
        it "should check against the specified order" do
          order.stub :update_attributes
          controller.should_receive(:authorize!).with(:edit, specified_order, token)
          spree_post :update, :order => { :email => "foo@bar.com" }, :id => specified_order.number, :token => token
        end
      end

      context '#empty' do
        it 'should check if user is authorized for :edit' do
          controller.should_receive(:authorize!).with(:edit, order, token)
          spree_post :empty, :token => token
        end
        it "should check against the specified order" do
          controller.should_receive(:authorize!).with(:edit, specified_order, token)
          spree_post :empty, :id => specified_order.number, :token => token
        end
      end

      context "#show" do
        it "should check against the specified order" do
          controller.should_receive(:authorize!).with(:edit, specified_order, token)
          spree_get :show, :id => specified_order.number, :token => token
        end
      end
    end

    context 'when no authenticated user' do
      let(:order) { create(:order, :number => 'R123') }

      context '#show' do
        context 'when token parameter present' do
          it 'should store as guest_token in session' do
            spree_get :show, {:id => 'R123', :token => order.token }
            session[:access_token].should == order.token
          end
        end

        context 'when no token present' do
          it 'should not store a guest_token in the session' do
            spree_get :show, {:id => 'R123'}
            session[:access_token].should be_nil
          end

          it 'should respond with 404' do
            spree_get :show, {:id => 'R123'}
            response.code.should == '404'
          end
        end
      end

    end
  end
end
