# frozen_string_literal: true

module Spree
  module Webhooks
    module Subscribers
      class HandleRequest
        def initialize(body:, event_name:, subscriber:)
          @body = JSON.parse(body)
          @event_name = event_name
          @subscriber = subscriber
        end

        def call
          Rails.logger.debug(msg("sending to '#{url}'"))
          Rails.logger.debug(msg("body: #{body}"))

          return process(:warn, msg("can not make a request to '#{url}'")) if unprocessable_uri?
          return process(:warn, msg("failed for '#{url}'")) if failed_request?

          process(:debug, msg("success for URL '#{url}'"))
        end

        private

        attr_reader :body, :event_name, :subscriber

        delegate :execution_time, :failed_request?, :response_code, :success?, :unprocessable_uri?, to: :request
        delegate :id, :url, to: :subscriber
        delegate :created_at, :id, to: :event, prefix: true

        def process(log_level, msg)
          Rails.logger.public_send(log_level, msg)
          update_event(msg)
          nil
        end

        def update_event(msg)
          Spree::Webhooks::Event.
            find(event_id).
            update(
              execution_time: execution_time,
              request_errors: msg,
              response_code: response_code,
              success: success?,
            )
        end

        def request
          @request ||=
            Spree::Webhooks::Subscribers::MakeRequest.new(body: body_with_event_metadata, url: url)
        end

        def body_with_event_metadata
          body.
            merge(event_created_at: event_created_at, event_id: event_id, event_type: event.name).
            to_json
        end

        def event
          @event ||= Spree::Webhooks::Event.create(name: event_name, subscriber_id: id, url: url)
        end

        def msg(msg)
          "[SPREE WEBHOOKS] '#{event_name}' #{msg}"
        end
      end
    end
  end
end
