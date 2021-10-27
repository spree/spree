require 'spec_helper'

describe Spree::Webhooks::Subscribers::HandleRequest do
  describe '#call' do
    subject { described_class.new(body: body, event: event, subscriber: subscriber) }

    let(:body) { { data: {} }.to_json }
    let(:event) { 'order.canceled' }
    let(:headers) { { 'Content-Type' => 'application/json' } }
    let(:request_double) { instance_double(Spree::Webhooks::Subscribers::MakeRequest) }
    let(:subscriber) { create(:subscriber, url: url) }
    let(:subscriber_id) { subscriber.id }
    let(:url) { 'http://google.com/' }

    shared_examples 'logging and creating a webhooks event' do |with_log_level:|
      before do
        allow(subject).to receive(:request).and_return(request_double)
        allow(request_double).to(
          receive_messages(
            execution_time: execution_time,
            failed_request?: failed_request,
            response_code: response_code,
            success?: success,
            unprocessable_uri?: unprocessable_uri
          )
        )
      end

      it "#{with_log_level} logs before the request" do
        allow(Rails.logger).to receive(with_log_level)
        subject.call
        expect(Rails.logger).to have_received(with_log_level).with(log_msg)
      end

      it 'creates a webhooks event with the process info' do
        expect { subject.call }.to change {
          Spree::Webhooks::Event.pluck(
            :execution_time, :request_errors, :response_code, :subscriber_id, :success, :url
          )
        }.from([]).to([[execution_time, log_msg, response_code.to_s, subscriber_id, success, url]])
      end

      it { expect(subject.call).to eq(nil) }
    end

    context 'with an unprocessable uri' do
      let(:execution_time) { 0 }
      let(:failed_request) { true }
      let(:log_msg) { "[SPREE WEBHOOKS] 'order.canceled' can not make a request to 'http://google.com/'" }
      let(:response_code) { 0 }
      let(:success) { false }
      let(:unprocessable_uri) { true }

      it_behaves_like 'logging and creating a webhooks event', with_log_level: :warn
    end

    context 'with a processable uri' do
      let(:unprocessable_uri) { false }

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
        let(:execution_time) { 0 }
        let(:failed_request) { true }
        let(:log_msg) { "[SPREE WEBHOOKS] 'order.canceled' failed for 'http://google.com/'" }
        let(:response_code) { 0 }
        let(:success) { false }

        it_behaves_like 'logging and creating a webhooks event', with_log_level: :warn
      end

      context 'without a failed request' do
        let(:execution_time) { rand(1..999999) }
        let(:failed_request) { false }
        let(:log_msg) { "[SPREE WEBHOOKS] 'order.canceled' success for URL 'http://google.com/'" }
        let(:response_code) { 200 }
        let(:success) { true }

        it_behaves_like 'logging and creating a webhooks event', with_log_level: :debug
      end
    end
  end
end
