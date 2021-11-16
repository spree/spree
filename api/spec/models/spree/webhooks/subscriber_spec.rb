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
    subject { described_class.supported_events(model_name) }

    context 'when only default events' do
      let(:model_name) { :address }

      it 'returns the resource.create, resource.update and resource.delete events' do
        expect(subject).to eq(%w[address.create address.update address.delete])
      end
    end

    context 'when it has additional events' do
      before do
        allow(Spree::Webhooks::Subscriber::SUPPORTED_CUSTOM_EVENTS).to receive(:include?).with(model_name).and_return(true)
        allow(Spree::Webhooks::Subscriber::SUPPORTED_CUSTOM_EVENTS).to receive(:[]).with(model_name).and_return(additional_events)
      end

      let(:additional_events) { %W[#{model_name}.event1 #{model_name}.event2] }
      let(:default_events) { %W[#{model_name}.create #{model_name}.update #{model_name}.delete] }
      let(:model_name) { :product }

      it 'returns the default events and the additional events' do
        expect(subject).to eq(default_events + additional_events)
      end
    end
  end
end
