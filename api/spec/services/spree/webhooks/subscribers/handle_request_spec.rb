require 'spec_helper'

describe Spree::Webhooks::Subscribers::HandleRequest do
  describe '#call' do
    subject { described_class.new(body: body, event: event, subscriber_id: subscriber_id, url: url) }

    let(:body) { { foo: :bar }.to_json }
    let(:event) { 'order.canceled' }
    let(:headers) { { 'Content-Type' => 'application/json' } }
    let(:request_double) { instance_double(Spree::Webhooks::Subscribers::MakeRequest) }
    let(:subscriber_id) { 1 }
    let(:url) { 'http://google.com/' }

    context 'with an unprocessable uri' do
      let(:url) { '' }
      let(:log_msg) { "[SPREE WEBHOOKS] 'order.canceled' can not make a request to ''" }
      let(:request_double) do
        double(execution_time: 0, response_code: 0, success: false, unprocessable_uri?: true)
      end

      before do
        allow(subject).to receive(:request).and_return(request_double)
      end

      it 'debug logs before the request' do
        allow(Rails.logger).to receive(:warn)
        subject.call
        expect(Rails.logger).to have_received(:warn).with(log_msg)
      end

      it 'creates a webhook event with the process data' do
        expect { subject.call }.to change {
          Spree::Webhooks::Event.pluck(
            :execution_time, :request_errors, :response_code, :subscriber_id, :success, :url
          )
        }.from([]).to([[0, log_msg, "0", subscriber_id, false, url]])
      end

      it { expect(subject.call).to eq(nil) }
    end

    context 'with a processable uri' do
      before { stub_request(:post, url) }

      it 'debug logs before the request' do
        allow(Rails.logger).to receive(:debug)
        subject.call
        message_fst = "[SPREE WEBHOOKS] 'order.canceled' sending to 'http://google.com/'"
        message_snd = "[SPREE WEBHOOKS] 'order.canceled' body: #{body}"
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
          message = "[SPREE WEBHOOKS] 'order.canceled' failed for 'http://google.com/'"
          expect(Rails.logger).to have_received(:warn).with(message)
        end

        it { expect(subject.call).to eq(nil) }
      end

      context 'without a failed request' do
        let(:message) { "[SPREE WEBHOOKS] 'order.canceled' success for URL 'http://google.com/'" }

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
