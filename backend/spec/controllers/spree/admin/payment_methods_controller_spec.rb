require 'spec_helper'

module Spree
  class GatewayWithPassword < PaymentMethod
    preference :password, :string, default: 'password'
  end

  describe Admin::PaymentMethodsController, type: :controller do
    stub_authorization!

    let(:payment_method) { GatewayWithPassword.create!(name: 'Bogus', preferred_password: 'haxme') }

    # regression test for #2094
    it 'does not clear password on update' do
      expect(payment_method.preferred_password).to eq('haxme')
      spree_put :update, id: payment_method.id, payment_method: { type: payment_method.class.to_s, preferred_password: '' }
      expect(response).to redirect_to(spree.edit_admin_payment_method_path(payment_method))

      payment_method.reload
      expect(payment_method.preferred_password).to eq('haxme')
    end

    it 'saves payment method preferences on update' do
      spree_put :update,
                id: payment_method.id,
                payment_method: {
                  type: payment_method.class.to_s,
                  name: 'Bogus'
                },
                gateway_with_password: {
                  preferred_password: 'abc'
                }

      payment_method.reload
      expect(payment_method.preferred_password).to eq('abc')
    end

    context 'tries to save invalid payment' do
      it "doesn't break, responds nicely" do
        expect do
          spree_post :create, payment_method: { name: '', type: 'Spree::Gateway::Bogus' }
        end.not_to raise_error
      end
    end

    it 'can create a payment method of a valid type' do
      expect do
        spree_post :create, payment_method: { name: 'Test Method', type: 'Spree::Gateway::Bogus' }
      end.to change(Spree::PaymentMethod, :count).by(1)

      expect(response).to be_redirect
      expect(response).to redirect_to spree.edit_admin_payment_method_path(assigns(:payment_method))
    end

    it 'can not create a payment method of an invalid type' do
      expect do
        spree_post :create, payment_method: { name: 'Invalid Payment Method', type: 'Spree::InvalidType' }
      end.to change(Spree::PaymentMethod, :count).by(0)

      expect(response).to be_redirect
      expect(response).to redirect_to spree.new_admin_payment_method_path
    end
  end
end
