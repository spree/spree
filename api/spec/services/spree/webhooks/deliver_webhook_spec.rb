# frozen_string_literal: true

require 'spec_helper'

module Spree
  module Webhooks
    describe DeliverWebhook do
      let(:store) { create(:store) }
      let(:webhook_endpoint) { create(:webhook_endpoint, store: store) }
      let(:delivery) { create(:webhook_delivery, :pending, webhook_endpoint: webhook_endpoint) }
      let(:secret_key) { webhook_endpoint.secret_key }

      describe '.call' do
        context 'with successful response' do
          before do
            stub_request(:post, delivery.url)
              .to_return(status: 200, body: '{"status":"ok"}', headers: { 'Content-Type' => 'application/json' })
          end

          it 'marks delivery as successful' do
            described_class.call(delivery: delivery, secret_key: secret_key)

            delivery.reload
            expect(delivery.success).to be true
            expect(delivery.response_code).to eq(200)
            expect(delivery.response_body).to eq('{"status":"ok"}')
            expect(delivery.delivered_at).to be_present
            expect(delivery.execution_time).to be_present
          end

          it 'sends correct headers' do
            described_class.call(delivery: delivery, secret_key: secret_key)

            expect(WebMock).to have_requested(:post, delivery.url)
              .with(headers: {
                'Content-Type' => 'application/json',
                'User-Agent' => 'Spree-Webhooks/1.0',
                'X-Spree-Webhook-Event' => delivery.event_name
              })
          end

          it 'includes HMAC signature in headers' do
            expected_signature = OpenSSL::HMAC.hexdigest('SHA256', secret_key, delivery.payload.to_json)

            described_class.call(delivery: delivery, secret_key: secret_key)

            expect(WebMock).to have_requested(:post, delivery.url)
              .with(headers: { 'X-Spree-Webhook-Signature' => expected_signature })
          end

          it 'sends payload as JSON body' do
            described_class.call(delivery: delivery, secret_key: secret_key)

            expect(WebMock).to have_requested(:post, delivery.url)
              .with(body: delivery.payload.to_json)
          end
        end

        context 'with 201 response' do
          before do
            stub_request(:post, delivery.url)
              .to_return(status: 201, body: '')
          end

          it 'marks delivery as successful' do
            described_class.call(delivery: delivery, secret_key: secret_key)

            delivery.reload
            expect(delivery.success).to be true
            expect(delivery.response_code).to eq(201)
          end
        end

        context 'with 4xx response' do
          before do
            stub_request(:post, delivery.url)
              .to_return(status: 404, body: 'Not Found')
          end

          it 'marks delivery as failed' do
            described_class.call(delivery: delivery, secret_key: secret_key)

            delivery.reload
            expect(delivery.success).to be false
            expect(delivery.response_code).to eq(404)
            expect(delivery.response_body).to eq('Not Found')
          end
        end

        context 'with 5xx response' do
          before do
            stub_request(:post, delivery.url)
              .to_return(status: 500, body: 'Internal Server Error')
          end

          it 'marks delivery as failed' do
            described_class.call(delivery: delivery, secret_key: secret_key)

            delivery.reload
            expect(delivery.success).to be false
            expect(delivery.response_code).to eq(500)
          end
        end

        context 'with timeout' do
          before do
            stub_request(:post, delivery.url).to_timeout
            allow(Rails.error).to receive(:report)
          end

          it 'marks delivery as failed with timeout error' do
            described_class.call(delivery: delivery, secret_key: secret_key)

            delivery.reload
            expect(delivery.success).to be false
            expect(delivery.response_code).to be_nil
            expect(delivery.error_type).to eq('timeout')
            expect(delivery.request_errors).to be_present
          end

          it 'reports error to Rails.error' do
            described_class.call(delivery: delivery, secret_key: secret_key)

            expect(Rails.error).to have_received(:report).with(
              an_instance_of(Net::OpenTimeout),
              context: { webhook_delivery_id: delivery.id, url: delivery.url }
            )
          end
        end

        context 'with connection error' do
          before do
            stub_request(:post, delivery.url).to_raise(Errno::ECONNREFUSED)
            allow(Rails.error).to receive(:report)
          end

          it 'marks delivery as failed with connection error' do
            described_class.call(delivery: delivery, secret_key: secret_key)

            delivery.reload
            expect(delivery.success).to be false
            expect(delivery.response_code).to be_nil
            expect(delivery.error_type).to eq('connection_error')
            expect(delivery.request_errors).to be_present
          end

          it 'reports error to Rails.error' do
            described_class.call(delivery: delivery, secret_key: secret_key)

            expect(Rails.error).to have_received(:report).with(
              an_instance_of(Errno::ECONNREFUSED),
              context: { webhook_delivery_id: delivery.id, url: delivery.url }
            )
          end
        end

        context 'with large response body' do
          let(:large_body) { 'x' * 15_000 }

          before do
            stub_request(:post, delivery.url)
              .to_return(status: 200, body: large_body)
          end

          it 'truncates the response body' do
            described_class.call(delivery: delivery, secret_key: secret_key)

            delivery.reload
            expect(delivery.response_body.length).to be <= 10_003 # 10_000 + '...'
          end
        end
      end
    end
  end
end
