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
          Rails.logger.debug(msg("body: #{body_with_event_metadata}"))

          if request.unprocessable_uri?
            return process(:warn, msg("can not make a request to '#{url}'")) 
          end
          return process(:warn, msg("failed for '#{url}'")) if request.failed_request?

          process(:debug, msg("success for URL '#{url}'"))
        end

        private

        attr_reader :body, :event_name, :subscriber

        delegate :url, to: :subscriber

        def process(log_level, msg)
          Rails.logger.public_send(log_level, msg)
          make_request
          update_event(msg)
          nil
        end

        def request
          @request ||=
            Spree::Webhooks::Subscribers::MakeRequest.new(body: body_with_event_metadata, url: url)
        end
        alias make_request request

        def body_with_event_metadata
          body.
            merge(event_created_at: event.created_at, event_id: event.id, event_type: event.name).
            to_json
        end

        def event
          @event ||= Spree::Webhooks::Event.create!(
            name: event_name, subscriber_id: subscriber.id, url: url
          )
        end

        def update_event(msg)
          event.update(
            execution_time: request.execution_time,
            request_errors: msg,
            response_code: request.response_code,
            success: request.success?
          )
        end

        def msg(msg)
          "[SPREE WEBHOOKS] '#{event_name}' #{msg}"
        end
      end
    end
  end
end
