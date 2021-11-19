# frozen_string_literal: true

module Spree
  module Webhooks
    module Subscribers
      class HandleRequest
        def initialize(body:, event:, subscriber:)
          @body = body
          @event = event
          @event_id = body[:event_id]
          @subscriber = subscriber
        end

        def call
          Rails.logger.debug(msg("sending to '#{url}'"))
          Rails.logger.debug(msg("body: #{body}"))

          return create_event(:warn, msg("can not make a request to '#{url}'")) if unprocessable_uri?
          return create_event(:warn, msg("failed for '#{url}'")) if failed_request?

          create_event(:debug, msg("success for URL '#{url}'"))
        end

        private

        attr_reader :body, :event, :event_id, :subscriber, :url

        delegate :execution_time, :failed_request?, :response_code, :success?, :unprocessable_uri?,
                 to: :request
        delegate :id, :url, to: :subscriber

        def request
          @request ||= Spree::Webhooks::Subscribers::MakeRequest.new(body: body, url: url)
        end

        def create_event(log_level, msg)
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
              subscriber_id: id,
              success: success?,
              url: url
            )
        end

        def msg(msg)
          "[SPREE WEBHOOKS] '#{event}' #{msg}"
        end
      end
    end
  end
end
