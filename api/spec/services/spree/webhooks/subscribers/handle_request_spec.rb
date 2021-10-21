require 'spec_helper'

describe Spree::Webhooks::Subscribers::HandleRequest do
  describe '#call' do
    subject { described_class.new(body: body, event: event, url: url) }

    let(:body) { { foo: :bar }.to_json }
    let(:event) { 'order.cancel' }
    let(:headers) { { 'Content-Type' => 'application/json' } }
    let(:request_double) { instance_double(Spree::Webhooks::Subscribers::MakeRequest) }
    let(:url) { 'http://google.com/' }

    context 'with an unexpected body' do
      let(:body) { '' }

      it 'does not instantiate a new request' do
        expect(Spree::Webhooks::Subscribers::MakeRequest).not_to receive(:new)
        subject.call
      end

      it { expect(subject.call).to eq(nil) }
    end

    context 'with an unprocessable uri' do
      let(:url) { '' }

      before do
        allow(subject).to receive(:request).and_return(request_double)
        allow(request_double).to receive(:unprocessable_uri?).and_return(true)
      end

      it 'debug logs before the request' do
        allow(Rails.logger).to receive(:warn)
        subject.call
        message = "[SPREE WEBHOOKS] 'order.cancel' can not make a request to ''"
        expect(Rails.logger).to have_received(:warn).with(message)
      end

      it { expect(subject.call).to eq(nil) }
    end

    context 'with a processable uri' do
      before { stub_request(:post, url) }

      it 'debug logs before the request' do
        allow(Rails.logger).to receive(:debug)
        subject.call
        message_fst = "[SPREE WEBHOOKS] 'order.cancel' sending to 'http://google.com/'"
        message_snd = "[SPREE WEBHOOKS] 'order.cancel' body: #{body}"
        expect(Rails.logger).to have_received(:debug).with(message_fst)
        expect(Rails.logger).to have_received(:debug).with(message_snd)
      end

      context 'with a failed request' do
        before do
          allow(subject).to receive(:request).and_return(request_double)
          allow(request_double).to receive(:unprocessable_uri?).and_return(false)
          allow(request_double).to receive(:failed_request?).and_return(true)
        end

        it 'warn logs after the request' do
          allow(Rails.logger).to receive(:warn)
          subject.call
          message = "[SPREE WEBHOOKS] 'order.cancel' failed for 'http://google.com/'"
          expect(Rails.logger).to have_received(:warn).with(message)
        end

        it { expect(subject.call).to eq(nil) }
      end

      context 'without a failed request' do
        let(:message) { "[SPREE WEBHOOKS] 'order.cancel' success for URL 'http://google.com/'" }

        it 'debug logs after the request' do
          allow(Rails.logger).to receive(:debug)
          subject.call
          expect(Rails.logger).to have_received(:debug).with(message)
        end

        it 'returns the debug logger' do
          expect(subject.call).to eq(Rails.logger.debug(message))
        end
      end
    end
  end
end
