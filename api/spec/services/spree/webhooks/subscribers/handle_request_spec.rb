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
      Spree::Api::V2::Platform::AddressSerializer.new(
        resource,
        include: Spree::Api::V2::Platform::AddressSerializer.relationships_to_serialize.keys
      ).serializable_hash.to_json
    end
    let(:event_name) { 'order.canceled' }
    let(:event) { Spree::Webhooks::Event.find_by(name: event_name, subscriber_id: subscriber.id, url: url) }
    let(:make_request_double) { instance_double(Spree::Webhooks::Subscribers::MakeRequest) }
    let(:subscriber) { create(:subscriber, :active, subscriptions: [event_name], url: url) }
    let(:url) { 'http://google.com/' }
    let(:resource) { create(:address) }

    shared_examples 'logging and creating a webhooks event' do |with_log_level:|
      before { stub_request(:post, url) }

      context 'before making the request' do
        let(:body_with_event_metadata) do
          JSON.parse(webhook_payload_body).merge(
            event_created_at: event.created_at,
            event_id: event.id,
            event_type: event.name
          ).to_json
        end

        it 'debug logs' do
          allow(Rails.logger).to receive(:debug)
          allow(Spree::Webhooks::Subscribers::MakeRequest).to receive(:new).and_call_original
          subject.call
          message_fst = "[SPREE WEBHOOKS] 'order.canceled' sending to 'http://google.com/'"
          message_snd = "[SPREE WEBHOOKS] 'order.canceled' webhook_payload_body: #{body_with_event_metadata}"
          expect(Rails.logger).to have_received(:debug).with(message_fst)
          expect(Rails.logger).to have_received(:debug).with(message_snd)
          expect(Spree::Webhooks::Subscribers::MakeRequest).to(
            have_received(:new).with(webhook_payload_body: body_with_event_metadata, url: url)
          )
        end

        it "#{with_log_level} logs" do
          # in this case the content of body isn't necessary
          expect(Spree::Webhooks::Subscribers::MakeRequest).to(
            receive(:new).with(hash_including(url: url)).and_return(make_request_double)
          )
          expect(make_request_double).to(
            receive_messages(
              execution_time: execution_time,
              response_code: response_code,
              success?: success,
              unprocessable_uri?: unprocessable_uri
            )
          )
          allow(Rails.logger).to receive(with_log_level)
          subject.call
          expect(Rails.logger).to have_received(with_log_level).with(log_msg)
        end
      end

      it 'updates the event record created previously with the missing data' do
        expect(Spree::Webhooks::Subscribers::MakeRequest).to(
          receive(:new).with(hash_including(url: url)).and_return(make_request_double)
        )
        expect(make_request_double).to(
          receive_messages(
            execution_time: execution_time,
            response_code: response_code,
            success?: success,
            unprocessable_uri?: unprocessable_uri
          )
        )
        expect { subject.call }.to change {
          Spree::Webhooks::Event.
          all.
          as_json(except: %i[id created_at id preferences updated_at]).
          map(&:values)
        }.from(
          []
        ).to(
          [[execution_time, event_name, log_msg, response_code.to_s, subscriber.id, success, url]]
        )
      end

      it { expect(subject.call).to eq(nil) }
    end

    context 'with an unprocessable uri' do
      let(:execution_time) { 0 }
      let(:log_msg) { "[SPREE WEBHOOKS] 'order.canceled' can not make a request to 'http://google.com/'" }
      let(:response_code) { 0 }
      let(:success) { false }
      let(:unprocessable_uri) { true }

      it_behaves_like 'logging and creating a webhooks event', with_log_level: :warn
    end

    context 'with a processable uri' do
      let(:unprocessable_uri) { false }

      before do
        allow(make_request_double).to(
          receive_messages(
            failed_request?: failed_request
          )
        )
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

    context 'full flow' do
      let(:webhook_payload_body) do
        Spree::Api::V2::Platform::OrderSerializer.new(
          order.reload,
          include: Spree::Api::V2::Platform::OrderSerializer.relationships_to_serialize.keys
        ).serializable_hash
      end
      let(:event) { Spree::Webhooks::Event.find_by(name: event_name, subscriber_id: subscriber.id, url: url) }
      let(:event_name) { 'order.placed' }
      let(:order) { create(:order, email: 'test@example.com') }

      before do
        stub_request(:post, url)
        subscriber
      end

      it 'queues a job without event data on the webhook body right after the event is executed', :job do
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

      context 'after executing the job' do
        let(:body_with_event_metadata) do
          webhook_payload_body.merge(
            event_created_at: event.created_at, event_id: event.id, event_type: event.name
          ).to_json
        end

        it 'adds the event data to the body' do
          with_webhooks_enabled do
            allow(Spree::Webhooks::Subscribers::MakeRequest).to receive(:new).and_call_original
            order.finalize!
            expect(Spree::Webhooks::Subscribers::MakeRequest).to(
              have_received(:new).with(webhook_payload_body: body_with_event_metadata, url: url)
            )
          end
        end
      end
    end

    context 'when the event can not be created' do
      it 'raises ActiveRecord::RecordInvalid'  do
        with_webhooks_enabled do
          expect do
            described_class.new(
              webhook_payload_body: webhook_payload_body,
              event_name: nil, # forces a validation error
              subscriber: subscriber
            ).call
          end.to raise_error(ActiveRecord::RecordInvalid)
        end
      end
    end
  end
end
