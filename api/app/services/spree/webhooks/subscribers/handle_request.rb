# frozen_string_literal: true

module Spree
  module Webhooks
    module Subscribers
      class HandleRequest
        def initialize(body:, event:, subscriber_id:, url:)
          @body = body
          @event = event
          @subscriber_id = subscriber_id
          @url = url
        end

        def call
          Rails.logger.debug(webhooks_log("sending to '#{url}'"))
          Rails.logger.debug(webhooks_log("body: #{body}"))

          if request.unprocessable_uri?
            log_msg = webhooks_log("can not make a request to '#{url}'")
            Rails.logger.warn(log_msg)
            Spree::Webhooks::Event.create(
              execution_time: request.execution_time,
              request_errors: log_msg,
              response_code: request.response_code,
              subscriber_id: subscriber_id,
              success: request.success,
              url: url
            )
            return
          end

          if request.failed_request?
            Rails.logger.warn(webhooks_log("failed for '#{url}'"))
            return
          end

          Rails.logger.debug(webhooks_log("success for URL '#{url}'"))
        end

        private

        attr_reader :body, :event, :subscriber_id, :url

        def request
          @request ||= Spree::Webhooks::Subscribers::MakeRequest.new(body: body, url: url)
        end

        def webhooks_log(msg)
          "[SPREE WEBHOOKS] '#{event}' #{msg}"
        end
      end
    end
  end
end
