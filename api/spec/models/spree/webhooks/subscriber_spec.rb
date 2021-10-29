require 'spec_helper'

describe Spree::Webhooks::Subscriber do
  describe 'validations' do
    context 'url format (UrlValidator)' do
      it 'is invalid with an invalid url' do
        endpoint = described_class.new(url: 'google.com')
        expect(endpoint.valid?).to be(false)
      end

      it 'is valid with a valid url' do
        endpoint = described_class.new(url: 'http://google.com/')
        expect(endpoint.valid?).to be(true)
      end
    end

    context 'url path' do
      it 'is invalid a url without path' do
        endpoint = described_class.new(url: 'http://google.com')
        expect(endpoint.valid?).to be(false)
        expect(endpoint.errors.messages).to eq(url: ['the URL must have a path'])
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
end
