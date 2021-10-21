# frozen_string_literal: true

module Spree
  module Webhooks
    module Subscribers
      class HandleRequest
        def initialize(body:, event:, url:)
          @body = body
          @event = event
          @url = url
        end

        def call
          return if body == ''

          Rails.logger.debug(webhooks_log("sending to '#{url}'"))
          Rails.logger.debug(webhooks_log("body: #{body}"))

          if request.unprocessable_uri?
            Rails.logger.warn(webhooks_log("can not make a request to '#{url}'"))
            return
          end

          if request.failed_request?
            Rails.logger.warn(webhooks_log("failed for '#{url}'"))
            return
          end

          Rails.logger.debug(webhooks_log("success for URL '#{url}'"))
        end

        private

        attr_reader :body, :event, :url

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
