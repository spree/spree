require 'spec_helper'

describe Spree::Webhooks::Subscribers::HandleRequest do
  describe '#call' do
    subject do
      described_class.new(
        event_name: event_name,
        subscriber: subscriber,
        webhook_payload_body: webhook_payload_body
      )
    end

    let(:webhook_payload_body) do
      Spree::Api::V2::Platform::AddressSerializer.new(resource).serializable_hash.merge(
        event_created_at: event.created_at,
        event_id: event.id,
        event_type: event.name
      ).to_json
    end
    let(:event_name) { 'order.canceled' }
    let(:event) { create(:event, :blank, name: event_name, subscriber_id: subscriber.id, url: url) }
    let(:make_request_double) { instance_double(Spree::Webhooks::Subscribers::MakeRequest) }
    let(:subscriber) { create(:subscriber, :active, subscriptions: [event_name], url: url) }
    let(:url) { 'http://google.com/' }
    let(:resource) { create(:address) }

    shared_examples 'logging and creating a webhooks event' do |with_log_level:|
      before do
        expect(Spree::Webhooks::Event).to(
          receive(:create).
          with(name: event_name, subscriber_id: subscriber.id, url: url).
          and_return(event)
        )
        expect(Spree::Webhooks::Subscribers::MakeRequest).to(
          receive(:new).with(webhook_payload_body: webhook_payload_body, url: url).and_return(make_request_double)
        )
        allow(make_request_double).to(
          receive_messages(
            execution_time: execution_time,
            failed_request?: failed_request,
            response_code: response_code,
            success?: success,
            unprocessable_uri?: unprocessable_uri
          )
        )
      end

      it 'debug logs before the request' do
        allow(Rails.logger).to receive(:debug)
        subject.call
        message_fst = "[SPREE WEBHOOKS] 'order.canceled' sending to 'http://google.com/'"
        message_snd = "[SPREE WEBHOOKS] 'order.canceled' webhook_payload_body: #{JSON.parse(webhook_payload_body)}"
        expect(Rails.logger).to have_received(:debug).with(message_fst)
        expect(Rails.logger).to have_received(:debug).with(message_snd)
      end

      it "#{with_log_level} logs before the request" do
        allow(Rails.logger).to receive(with_log_level)
        subject.call
        expect(Rails.logger).to have_received(with_log_level).with(log_msg)
      end

      it 'updates the event record created previously with the missing data' do
        expect { subject.call }.to change {
          Spree::Webhooks::Event.
            find(event.id).
            as_json(except: %i[created_at id preferences updated_at]).
            values
        }.from(
          [nil, event_name, nil, nil, subscriber.id, nil, url]
        ).to(
          [execution_time, event_name, log_msg, response_code.to_s, subscriber.id, success, url]
        )
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

    context 'full flow' do
      let(:webhook_payload_body) { Spree::Api::V2::Platform::OrderSerializer.new(order.reload).serializable_hash }
      let(:body_with_event_metadata) { webhook_payload_body.merge(event_created_at: event.created_at, event_id: event.id, event_type: event.name).to_json }
      let(:event) { Spree::Webhooks::Event.find_by(name: event_name, subscriber_id: subscriber.id) }
      let(:event_name) { 'order.placed' }
      let(:order) { create(:order, email: 'test@example.com') }

      before do
        stub_request(:post, url)
        subscriber
      end

      it 'queues a job without event data on the webhook_payload_body right after the event is executed', :job do
        with_webhooks_enabled do
          order.finalize!
          expect(Spree::Webhooks::Subscribers::MakeRequestJob).to(
            have_been_enqueued.
            on_queue('spree_webhooks').
            with(webhook_payload_body.to_json, event_name, subscriber).
            once
          )
        end
      end

      it 'adds the event data to the webhook_payload_body after executing the job' do
        with_webhooks_enabled do
          allow(Spree::Webhooks::Subscribers::MakeRequest).to receive(:new).and_call_original
          order.finalize!
          expect(Spree::Webhooks::Subscribers::MakeRequest).to have_received(:new).with(webhook_payload_body: body_with_event_metadata, url: url)
        end
      end
    end
  end
end
