require 'spec_helper'

describe Spree::Admin::PaymentMethodsController, type: :controller do
  stub_authorization!

  render_views

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
    let(:payment_method_params) do
      {
        name: 'Bogus Gateway',
        type: 'Spree::Gateway::Bogus',
        description: 'Bogus Gateway Description',
        active: true,
        display_on: 'both',
        auto_capture: true,
        position: 1,
        preferred_dummy_key: 'DUMMY_KEY',
        preferred_dummy_secret_key: 'DUMMY_SECRET_KEY'
      }
    end

    it 'creates the payment method' do
      expect { post :create, params: { payment_method: payment_method_params } }.to change(Spree::Gateway::Bogus, :count).by(1)

      payment_method = Spree::Gateway::Bogus.last
      expect(payment_method.name).to eq('Bogus Gateway')
      expect(payment_method.description).to eq('Bogus Gateway Description')
      expect(payment_method.active).to be_truthy
      expect(payment_method.display_on).to eq('both')
      expect(payment_method.auto_capture).to be_truthy
      expect(payment_method.position).to eq(1)
      expect(payment_method.preferred_dummy_key).to eq('DUMMY_KEY')
      expect(payment_method.preferred_dummy_secret_key).to eq('DUMMY_SECRET_KEY')

      expect(response).to redirect_to(spree.edit_admin_payment_method_path(payment_method))
    end
  end

  describe '#update' do
    subject { put :update, params: { id: payment_method.to_param, payment_method: payment_method_params } }

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

      expect(response).to redirect_to(spree.edit_admin_payment_method_path(payment_method))
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

    context 'changing position' do
      let(:payment_method_params) do
        {
          position: 2
        }
      end

      it 'updates the payment method' do
        expect { subject }.to change { payment_method.reload.position }.to(2)
      end
    end

    context 'changing display_on' do
      let(:payment_method_params) do
        {
          display_on: 'back_end'
        }
      end

      it 'updates the payment method' do
        expect { subject }.to change { payment_method.reload.display_on }.to('back_end')
      end
    end

    context 'changing active' do
      let(:payment_method_params) do
        {
          active: false
        }
      end

      it 'updates the payment method' do
        expect { subject }.to change { payment_method.reload.active }.to(false)
      end
    end
  end
end
