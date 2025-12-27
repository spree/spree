# frozen_string_literal: true

module Spree
  # Logs all Spree events to Rails logger.
  #
  # Enabled by default. To disable, set Spree::Config.events_log_enabled = false
  #
  # Events are logged at info level. Sensitive parameters are filtered using
  # Rails.application.config.filter_parameters.
  #
  # @example Output
  #   [Spree Event] order.complete | payload: {"id"=>1} | 0.5ms
  #
  class EventLogSubscriber
    NAMESPACE = 'spree'

    class << self
      def attach_to_notifications
        # Always detach first to ensure clean state after code reload
        detach_from_notifications

        @subscription = ActiveSupport::Notifications.subscribe(/\.#{NAMESPACE}$/) do |name, start, finish, _id, payload|
          log_event(name, start, finish, payload)
        end

        @attached = true
        Rails.logger.info "[Spree Events] Event logging enabled"
      end

      def detach_from_notifications
        ActiveSupport::Notifications.unsubscribe(@subscription) if @subscription
        @subscription = nil
        @attached = false
      end

      def attached?
        @attached || false
      end

      private

      def log_event(name, start, finish, payload)
        spree_event = payload[:event]
        return unless spree_event

        event_name = spree_event.name
        event_payload = filter_sensitive_params(spree_event.payload)
        duration = ((finish - start) * 1000).round(2)

        Rails.logger.info "  \e[36m[Spree Event]\e[0m \e[1m#{event_name}\e[0m | payload: #{event_payload.inspect} | #{duration}ms"
      end

      def filter_sensitive_params(payload)
        parameter_filter.filter(payload)
      end

      def parameter_filter
        @parameter_filter ||= ActiveSupport::ParameterFilter.new(
          Rails.application.config.filter_parameters
        )
      end
    end
  end
end
