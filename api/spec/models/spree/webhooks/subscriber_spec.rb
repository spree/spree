require 'spec_helper'

describe Spree::Webhooks::Subscriber do
  describe 'before_save' do
    context 'with subscriptions' do
      let(:subscriptions) { ['order.placed', 'order.shipped'] }

      it 'json parses the subscriptions' do
        subscriber = create(:subscriber, subscriptions: subscriptions.to_json)
        expect(subscriber.subscriptions).to eq(subscriptions)
      end
    end

    context 'without subscriptions' do
      it 'json parses the subscriptions' do
        subscriber = create(:subscriber, subscriptions: nil)
        expect(subscriber.subscriptions).to eq(nil)
      end
    end
  end

  describe 'validations' do
    context 'url format (UrlValidator)' do
      it 'is invalid with an invalid url' do
        subscriber = described_class.new(url: 'google.com')
        expect(subscriber.valid?).to be(false)
      end

      it 'is valid with a valid url' do
        subscriber = described_class.new(url: 'http://google.com/')
        expect(subscriber.valid?).to be(true)
      end
    end

    context 'url path' do
      it 'is invalid a url without path' do
        subscriber = described_class.new(url: 'http://google.com')
        expect(subscriber.valid?).to be(false)
        expect(subscriber.errors.messages).to eq(url: ['the URL must have a path'])
      end
    end
  end

  describe '.with_urls_for' do
    subject { described_class.with_urls_for(event) }

    let(:event) { 'order.placed' }
    let(:subscriptions) { ['order.placed'] }
    let!(:subscriber) { described_class.create(url: url, subscriptions: subscriptions, active: true) }
    let(:url) { 'https://url1.com/' }

    context 'with subscriptions for the given event' do
      it { expect(subject).to eq([subscriber]) }
    end

    context 'without subscriptions for the given event, but "*"' do
      let(:subscriptions) { ['*'] }

      it { expect(subject).to eq([subscriber]) }
    end

    context 'without subscriptions for the given event' do
      let(:subscriptions) { ['order.updated'] }

      it { expect(subject).to be_empty }
    end
  end

  describe '.supported_events' do
    subject { described_class.supported_events }

    it 'includes the webhookable model in supported events list' do
      class WebhookableDummy < Spree::Base
        include Spree::Webhooks::HasWebhooks
      end

      expect(subject[:webhookable_dummy]).to contain_exactly('webhookable_dummy.create', 'webhookable_dummy.update', 'webhookable_dummy.delete')
    end
  end
end
