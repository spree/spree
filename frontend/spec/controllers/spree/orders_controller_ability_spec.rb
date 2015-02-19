require 'spec_helper'

module Spree
  describe OrdersController, type: :controller do
    let(:user) { create(:user) }
    let(:guest_user) { create(:user) }
    let(:order) { Spree::Order.create }

    context 'when an order exists in the cookies.signed' do
      let(:token) { 'some_token' }
      let(:specified_order) { create(:order) }

      before do
        cookies.signed[:guest_token] = token
        allow(controller).to receive_messages current_order: order
        allow(controller).to receive_messages spree_current_user: user
      end

      context '#populate' do
        it 'should check if user is authorized for :edit' do
          expect(controller).to receive(:authorize!).with(:edit, order, token)
          spree_post :populate
        end
        it "should check against the specified order" do
          expect(controller).to receive(:authorize!).with(:edit, specified_order, token)
          spree_post :populate, id: specified_order.number
        end
      end

      context '#edit' do
        it 'should check if user is authorized for :edit' do
          expect(controller).to receive(:authorize!).with(:edit, order, token)
          spree_get :edit
        end
        it "should check against the specified order" do
          expect(controller).to receive(:authorize!).with(:edit, specified_order, token)
          spree_get :edit, id: specified_order.number
        end
      end

      context '#update' do
        it 'should check if user is authorized for :edit' do
          allow(order).to receive :update_attributes
          expect(controller).to receive(:authorize!).with(:edit, order, token)
          spree_post :update, order: { email: "foo@bar.com" }
        end
        it "should check against the specified order" do
          allow(order).to receive :update_attributes
          expect(controller).to receive(:authorize!).with(:edit, specified_order, token)
          spree_post :update, order: { email: "foo@bar.com" }, id: specified_order.number
        end
      end

      context '#empty' do
        it 'should check if user is authorized for :edit' do
          expect(controller).to receive(:authorize!).with(:edit, order, token)
          spree_post :empty
        end
        it "should check against the specified order" do
          expect(controller).to receive(:authorize!).with(:edit, specified_order, token)
          spree_post :empty, id: specified_order.number
        end
      end

      context "#show" do
        it "should check against the specified order" do
          expect(controller).to receive(:authorize!).with(:edit, specified_order, token)
          spree_get :show, id: specified_order.number
        end
      end
    end

    context 'when no authenticated user' do
      let(:order) { create(:order, number: 'R123') }

      context '#show' do
        context 'when guest_token correct' do
          before { cookies.signed[:guest_token] = order.guest_token }

          it 'displays the page' do
            expect(controller).to receive(:authorize!).with(:edit, order, order.guest_token)
            spree_get :show, { id: 'R123' }
            expect(response.code).to eq('200')
          end
        end

        context 'when guest_token not present' do
          it 'should respond with 404' do
            spree_get :show, { id: 'R123'}
            expect(response.code).to eq('404')
          end
        end
      end
    end
  end
end
