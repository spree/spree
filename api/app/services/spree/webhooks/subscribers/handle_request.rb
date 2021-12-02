# frozen_string_literal: true

module Spree
  module Webhooks
    module Subscribers
      class HandleRequest
        def initialize(event_name:, subscriber:, webhook_payload_body:)
          @event_name = event_name
          @subscriber = subscriber
          @webhook_payload_body = JSON.parse(webhook_payload_body)
        end

        def call
          Rails.logger.debug(msg("sending to '#{url}'"))
          Rails.logger.debug(msg("webhook_payload_body: #{body_with_event_metadata}"))

          if request.unprocessable_uri?
            return process(:warn, msg("can not make a request to '#{url}'"))
          end
          return process(:warn, msg("failed for '#{url}'")) if request.failed_request?

          process(:debug, msg("success for URL '#{url}'"))
        end

        private

        attr_reader :webhook_payload_body, :event_name, :subscriber

        delegate :execution_time, :failed_request?, :response_code, :success?, :unprocessable_uri?, to: :request
        delegate :id, :url, to: :subscriber
        delegate :created_at, :id, to: :event, prefix: true

        def process(log_level, msg)
          Rails.logger.public_send(log_level, msg)
          make_request
          update_event(msg)
          nil
        end

        def request
          @request ||=
            Spree::Webhooks::Subscribers::MakeRequest.new(webhook_payload_body: body_with_event_metadata, url: url)
        end
        alias make_request request

        def body_with_event_metadata
          webhook_payload_body.
            merge(event_created_at: event_created_at, event_id: event_id, event_type: event.name).
            to_json
        end

        def event
          @event ||= Spree::Webhooks::Event.create!(
            name: event_name, subscriber_id: subscriber.id, url: url
          )
        end

        def update_event(msg)
          event.update(
            execution_time: execution_time,
            request_errors: msg,
            response_code: response_code,
            success: success?
          )
        end

        def msg(msg)
          "[SPREE WEBHOOKS] '#{event_name}' #{msg}"
        end
      end
    end
  end
end
