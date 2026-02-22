require 'spec_helper'

module Spree
  module Integrations
    class DummyIntegration < Spree::Integration
      validates :preferred_api_key, presence: true

      preference :api_key, :string

      def can_connect?
        true
      end
    end
  end
end

describe Spree::Admin::IntegrationsController, type: :controller do
  stub_authorization!

  let(:store) { Spree::Store.default }
  let(:integration_type) { Spree::Integrations::DummyIntegration }

  before do
    allow(Rails.application.config.spree).to receive(:integrations).and_return([integration_type])
    allow_any_instance_of(described_class).to receive(:current_store).and_return(store)
  end

  describe 'GET #new' do
    context 'without integration type param' do
      it 'redirects to integrations path' do
        get :new
        expect(response).to redirect_to(spree.admin_integrations_path)
      end
    end

    context 'with integration type param' do
      it 'renders new template' do
        get :new, params: { integration: { type: integration_type } }
        expect(response).to render_template(:new)
      end
    end

    context 'when integration already exists for store' do
      before do
        Spree::Integrations::DummyIntegration.create!(store: store, preferred_api_key: 'APIKEY')
      end

      it 'redirects to integrations path' do
        get :new, params: { integration: { type: integration_type } }
        expect(response).to redirect_to(spree.admin_integrations_path)
      end
    end
  end

  describe 'POST #create' do
    context 'with invalid integration type' do
      it 'redirects with error' do
        post :create, params: { integration: { type: 'Invalid' } }
        expect(response).to redirect_to(spree.admin_integrations_path)
        expect(flash[:error]).to be_present
      end
    end

    context 'with valid integration type' do
      it 'creates new integration' do
        expect {
          post :create, params: { integration: { type: integration_type, active: true, preferred_api_key: 'APIKEY' } }
        }.to change(Spree::Integrations::DummyIntegration, :count).by(1)

        integration = Spree::Integrations::DummyIntegration.first
        expect(response).to redirect_to(spree.edit_admin_integration_path(integration))
        expect(integration.preferred_api_key).to eq('APIKEY')
        expect(integration.active).to eq(true)
      end
    end

    context 'when integration cannot connect' do
      before do
        allow_any_instance_of(integration_type).to receive(:can_connect?).and_return(false)
      end

      it 'renders new with error' do
        post :create, params: { integration: { type: integration_type, preferred_api_key: 'WRONGKEY' } }
        expect(response).to render_template(:new)
        expect(response.status).to eq(422)
      end
    end
  end

  describe 'PUT #update' do
    let(:integration) { Spree::Integrations::DummyIntegration.create!(store: store, preferred_api_key: 'APIKEY') }

    it 'updates integration' do
      put :update, params: { id: integration.to_param, integration: { preferred_api_key: 'NEWKEY' } }
      expect(response).to redirect_to(spree.edit_admin_integration_path(integration))
      expect(integration.reload.preferred_api_key).to eq('NEWKEY')
    end
  end

  describe 'DELETE #destroy' do
    let!(:integration) { Spree::Integrations::DummyIntegration.create!(store: store, preferred_api_key: 'APIKEY') }

    it 'destroys the integration' do
      expect {
        delete :destroy, params: { id: integration.to_param }
      }.to change(Spree::Integrations::DummyIntegration, :count).by(-1)
    end

    it 'redirects to index with success flash' do
      delete :destroy, params: { id: integration.to_param }
      expect(response).to redirect_to(spree.admin_integrations_path)
      expect(flash[:success]).to be_present
    end
  end
end
