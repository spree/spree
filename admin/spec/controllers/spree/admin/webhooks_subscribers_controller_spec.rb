require 'spec_helper'

describe Spree::Admin::WebhooksSubscribersController, type: :controller do
  stub_authorization!

  render_views

  describe '#index' do
    let!(:webhook_subscriber) { create(:webhook_subscriber) }

    it 'responds successfully' do
      get :index
      expect(response).to be_successful
    end
  end

  describe '#show' do
    let(:webhook_subscriber) { create(:webhook_subscriber) }

    it 'responds successfully' do
      get :show, params: { id: webhook_subscriber.id }
      expect(response).to be_successful
    end

    it 'assigns the subscriber' do
      get :show, params: { id: webhook_subscriber.id }
      expect(assigns(:webhooks_subscriber)).to eq webhook_subscriber
    end
  end

  describe '#new' do
    it 'responds successfully' do
      get :new
      expect(response).to be_successful
    end
  end

  describe '#create' do
    let(:params) do
      {
        webhooks_subscriber: {
          url: 'https://example.com/webhook',
          active: true
        },
        subscribe_to_all_events: 'true'
      }
    end

    it 'creates a new webhooks subscriber' do
      expect {
        post :create, params: params
      }.to change(Spree::Webhooks::Subscriber, :count).by(1)

      expect(response).to redirect_to spree.admin_webhooks_subscriber_path(Spree::Webhooks::Subscriber.last)
    end

    it 'sets the attributes' do
      post :create, params: params
      subscriber = Spree::Webhooks::Subscriber.last
      expect(subscriber.url).to eq('https://example.com/webhook')
      expect(subscriber.active).to be true
      expect(subscriber.subscriptions).to eq(['*'])
    end

    context 'with selected events' do
      let(:params) do
        {
          webhooks_subscriber: {
            url: 'https://example.com/webhook',
            active: true,
            order: 'true'
          },
          subscribe_to_all_events: 'false'
        }
      end

      before do
        allow(Spree::Webhooks::Subscriber).to receive(:supported_events).and_return(
          { order: ['order.created', 'order.updated'] }
        )
      end

      it 'sets the selected subscriptions' do
        post :create, params: params
        subscriber = Spree::Webhooks::Subscriber.last
        expect(subscriber.subscriptions).to eq(['order.created', 'order.updated'])
      end
    end
  end

  describe '#update' do
    let!(:webhook_subscriber) { create(:webhook_subscriber) }
    let(:params) do
      {
        id: webhook_subscriber.id,
        webhooks_subscriber: {
          url: 'https://example.com/webhook-updated',
          active: false
        },
        subscribe_to_all_events: 'true'
      }
    end

    it 'updates the webhooks subscriber' do
      put :update, params: params
      webhook_subscriber.reload
      expect(webhook_subscriber.url).to eq('https://example.com/webhook-updated')
      expect(webhook_subscriber.active).to be false
      expect(webhook_subscriber.subscriptions).to eq(['*'])

      expect(response).to redirect_to spree.admin_webhooks_subscriber_path(webhook_subscriber)
    end
  end

  describe '#destroy' do
    let!(:webhook_subscriber) { create(:webhook_subscriber) }

    it 'deletes the webhooks subscriber' do
      expect {
        delete :destroy, params: { id: webhook_subscriber.id }
      }.to change(Spree::Webhooks::Subscriber, :count).by(-1)

      expect(response).to redirect_to spree.admin_webhooks_subscribers_path
    end
  end
end
