require 'spec_helper'

module Spree
  describe OrdersController, type: :controller do
    let(:user) { create(:user) }
    let(:guest_user) { create(:user) }
    let(:order) { Spree::Order.create }

    context 'when an order exists in the cookies.signed' do
      let(:token) { 'some_token' }
      let(:specified_order) { create(:order) }
      let!(:variant) { create(:variant) }

      before do
        cookies.signed[:token] = token
        allow(controller).to receive_messages current_order: order
        allow(controller).to receive_messages spree_current_user: user
      end

      context '#edit' do
        it 'checks if user is authorized for :edit' do
          expect(controller).to receive(:authorize!).with(:edit, order, token)
          get :edit
        end
        it 'checks against the specified order' do
          expect(controller).to receive(:authorize!).with(:edit, specified_order, token)
          get :edit, params: { id: specified_order.number }
        end
      end

      context '#update' do
        it 'checks if user is authorized for :edit' do
          allow(order).to receive :update
          expect(controller).to receive(:authorize!).with(:edit, order, token)
          post :update, params: { order: { email: 'foo@bar.com' } }
        end
        it 'checks against the specified order' do
          allow(order).to receive :update
          expect(controller).to receive(:authorize!).with(:edit, specified_order, token)
          post :update, params: { order: { email: 'foo@bar.com' }, id: specified_order.number }
        end
      end

      context '#empty' do
        it 'checks if user is authorized for :edit' do
          expect(controller).to receive(:authorize!).with(:edit, order, token)
          post :empty
        end
        it 'checks against the specified order' do
          expect(controller).to receive(:authorize!).with(:edit, specified_order, token)
          post :empty, params: { id: specified_order.number }
        end
      end

      context '#show' do
        it 'checks against the specified order' do
          expect(controller).to receive(:authorize!).with(:show, specified_order, token)
          get :show, params: { id: specified_order.number }
        end
      end
    end

    context 'when no authenticated user' do
      let(:order) { create(:order, number: 'R123') }

      context '#show' do
        context 'when token correct' do
          before { cookies.signed[:token] = order.token }

          it 'displays the page' do
            expect(controller).to receive(:authorize!).with(:show, order, order.token)
            get :show, params: { id: 'R123' }
            expect(response.code).to eq('200')
          end
        end

        context 'when token not present' do
          it 'raises ActiveRecord::RecordNotFound' do
            expect { get :show, params: { id: 'R123' } }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end
      end
    end
  end
end
