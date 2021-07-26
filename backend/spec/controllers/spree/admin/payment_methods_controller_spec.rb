require 'spec_helper'

module Spree
  class GatewayWithPassword < PaymentMethod
    preference :password, :string, default: 'password'
  end

  describe Admin::PaymentMethodsController, type: :controller do
    stub_authorization!

    let(:store) { Spree::Store.default }
    let(:payment_method) { GatewayWithPassword.create!(name: 'Bogus', preferred_password: 'haxme', stores: [store]) }

    # regression test for #2094
    it 'does not clear password on update' do
      expect(payment_method.preferred_password).to eq('haxme')
      put :update, params: { id: payment_method.id, payment_method: { type: payment_method.class.to_s, preferred_password: '' } }
      expect(response).to redirect_to(spree.edit_admin_payment_method_path(payment_method))

      payment_method.reload
      expect(payment_method.preferred_password).to eq('haxme')
    end

    it 'saves payment method preferences on update' do
      put :update, params: {
                id: payment_method.id,
                payment_method: {
                  type: payment_method.class.to_s,
                  name: 'Bogus'
                },
                gateway_with_password: {
                  preferred_password: 'abc'
                }
              }

      payment_method.reload
      expect(payment_method.preferred_password).to eq('abc')
    end

    context 'tries to save invalid payment' do
      it "doesn't break, responds nicely" do
        expect do
          post :create, params: { payment_method: { name: '', type: 'Spree::Gateway::Bogus' } }
        end.not_to raise_error
      end
    end

    it 'can create a payment method of a valid type' do
      expect do
        post :create, params: { payment_method: { name: 'Test Method', type: 'Spree::Gateway::Bogus' } }
      end.to change(Spree::PaymentMethod, :count).by(1)

      expect(Spree::PaymentMethod.last.stores).to eq([store])

      expect(response).to redirect_to spree.edit_admin_payment_method_path(assigns(:payment_method))
    end

    it 'can not create a payment method of an invalid type' do
      expect do
        post :create, params: { payment_method: { name: 'Invalid Payment Method', type: 'Spree::InvalidType' } }
      end.to change(Spree::PaymentMethod, :count).by(0)

      expect(response).to redirect_to spree.new_admin_payment_method_path
    end

    describe '#index' do
      let!(:payment_method_1) { create(:payment_method, stores: [store]) }
      let!(:payment_method_2) { create(:payment_method, stores: [store]) }
      let!(:payment_method_3) { create(:payment_method, stores: [create(:store)]) }

      it 'assigns the payment_methods for current store' do
        get :index
        expect(assigns(:collection)).to include payment_method_1
        expect(assigns(:collection)).to include payment_method_2
        expect(assigns(:collection)).not_to include payment_method_3
      end
    end

    describe '#edit' do
      subject(:send_request) do
        get :edit, params: { id: payment_method }
      end

      it { expect(send_request).to have_http_status(:ok) }

      context 'payment method from different store' do
        let(:payment_method) { create(:payment_method, stores: [create(:store)]) }

        it { expect(send_request).to redirect_to(spree.admin_payment_methods_path) }
      end
    end

    describe '#destroy' do
      subject(:send_request) do
        delete :destroy, params: { id: payment_method, format: :js }
      end

      let(:payment_method) { create(:payment_method, stores: [store], name: 'Test') }

      shared_examples 'correct response' do
        it { expect(assigns(:payment_method)).to eq(payment_method) }
        it { expect(response).to have_http_status(:ok) }
      end

      context 'will successfully destroy payment_method' do
        describe 'returns response' do
          before { send_request }

          it_behaves_like 'correct response'
          it { expect(flash[:success]).to eq('Payment Method "Test" has been successfully removed!') }
        end
      end

      context 'cannot destroy payment_method from different store' do
        let(:payment_method) { create(:payment_method, stores: [create(:store)]) }

        it { expect(send_request).to redirect_to(spree.admin_payment_methods_path) }

        it do
          send_request
          expect(flash[:error]).to eq('Payment Method is not found')
        end
      end
    end
  end
end
