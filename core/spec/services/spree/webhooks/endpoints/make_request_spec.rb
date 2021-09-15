require 'spec_helper'

describe Spree::Webhooks::Endpoints::MakeRequest do
  describe '#call' do
    context 'with a valid URL' do
      let(:url) { 'https://google.com/' }
      let(:headers) { { 'Content-Type' => 'application/json' } }

      before { stub_request(:post, url) }

      it 'makes a post HTTP request to the given url' do
        described_class.call(url: url)
        expect(WebMock).to(
          have_requested(:post, url).with(body: {foo: :bar}.to_json, headers: headers).once
        )
      end

      it 'returns a success object with true success value' do
        expect(described_class.call(url: url).success).to eq(true)
      end
    end

    context 'without a valid URL' do
      let(:url) { '' }

      it 'does not instantiate a Net::HTTP::Post to make a request' do
        expect(Net::HTTP::Post).not_to receive(:new)
        expect(described_class.call(url: url).success).to eq(false)
      end
    end
  end
end
