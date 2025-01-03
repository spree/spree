require 'spec_helper'

describe Spree::Admin::PaymentMethodsController, type: :controller do
  stub_authorization!

  describe '#index' do
    it 'renders the index template' do
      get :index
      expect(response.status).to eq(200)
    end
  end

  describe '#new' do
    context 'without type param' do
      it 'redirects to payment methods index' do
        get :new
        expect(response).to redirect_to(spree.admin_payment_methods_path)
      end
    end

    context 'with type param' do
      it 'renders the new template' do
        get :new, params: { payment_method: { type: 'Spree::Gateway::Bogus' } }
        expect(response.status).to eq(200)
      end

      it 'assigns the type to the payment method' do
        get :new, params: { payment_method: { type: 'Spree::Gateway::Bogus' } }
        expect(assigns(:payment_method).type).to eq('Spree::Gateway::Bogus')
      end
    end
  end

  describe '#create' do
    it 'creates the payment method' do
      expect { post :create, params: { payment_method: { type: 'Spree::Gateway::Bogus' } } }.to change(Spree::Gateway::Bogus, :count).by(1)
    end
  end

  describe '#update' do
    subject { put :update, params: { id: payment_method.id, payment_method: payment_method_params } }

    let(:payment_method) { create(:credit_card_payment_method) }
    let(:payment_method_params) do
      {
        preferred_dummy_key: 'NEW_VALUE',
        preferred_dummy_secret_key: 'NEW_SECRET_VALUE'
      }
    end

    it 'updates the payment method' do
      expect { subject }.to change { payment_method.reload.preferred_dummy_key }.to('NEW_VALUE').and(
        change { payment_method.reload.preferred_dummy_secret_key }.to('NEW_SECRET_VALUE')
      )
    end

    context 'for empty password type preference' do
      let(:payment_method_params) do
        {
          preferred_dummy_key: 'NEW_VALUE',
          preferred_dummy_secret_key: ''
        }
      end

      it 'updates the payment method' do
        expect { subject }.to change { payment_method.reload.preferred_dummy_key }.to('NEW_VALUE')
        expect(payment_method.preferred_dummy_secret_key).to eq('SECRETKEY123')
      end
    end
  end
end
