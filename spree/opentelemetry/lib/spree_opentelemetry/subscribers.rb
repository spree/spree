require 'active_support/notifications'

module SpreeOpenTelemetry
  # Attaches one SpanSubscriber per Spree notification family — the
  # commerce-domain layer on top of the framework auto-instrumentation.
  # Span names come from bounded vocabularies (workflow keys, step names,
  # gateway actions, event names); attributes are PII-safe by construction
  # because the core notification payloads are (see
  # docs/plans/6.0-opentelemetry.md).
  module Subscribers
    class << self
      # Subscribes one span source per Spree notification family. Idempotent,
      # so a code reload cannot double-subscribe.
      #
      # @return [void]
      def attach!
        return if attached?

        tracer = SpreeOpenTelemetry.tracer
        @subscriptions = definitions(tracer).map do |notification_name, span_subscriber|
          ActiveSupport::Notifications.subscribe(notification_name, span_subscriber)
        end
        @subscriptions << domain_event_subscription
      end

      # @return [void]
      def detach!
        Array(@subscriptions).each { |subscription| ActiveSupport::Notifications.unsubscribe(subscription) }
        @subscriptions = nil
      end

      # @return [Boolean] whether the span sources are currently subscribed
      def attached?
        !@subscriptions.nil?
      end

      private

      def definitions(tracer)
        {
          'perform.spree_workflow' => SpanSubscriber.new(
            tracer: tracer,
            name: ->(payload) { payload[:workflow] },
            attributes: lambda do |payload|
              {
                'spree.workflow' => payload[:workflow],
                'spree.workflow.outcome' => payload[:outcome]
              }
            end,
            error: ->(payload) { 'workflow failed' if %w[failure error].include?(payload[:outcome]) }
          ),

          'step.spree_workflow' => SpanSubscriber.new(
            tracer: tracer,
            name: ->(payload) { "#{payload[:workflow]} #{payload[:step]}" },
            kind: ->(payload) { payload[:external] ? :client : :internal },
            attributes: lambda do |payload|
              {
                'spree.workflow' => payload[:workflow],
                'spree.workflow.step' => payload[:step].to_s,
                'spree.workflow.step.external' => payload[:external] == true,
                'spree.workflow.outcome' => payload[:outcome]
              }
            end,
            error: ->(payload) { 'step failed' if payload[:outcome] == 'failure' }
          ),

          'hooks.spree_workflow' => SpanSubscriber.new(
            tracer: tracer,
            name: ->(payload) { "#{payload[:workflow]} hooks #{payload[:hook]}" },
            skip: ->(payload) { payload[:handler_count].to_i.zero? },
            attributes: lambda do |payload|
              {
                'spree.workflow' => payload[:workflow],
                'spree.hook' => payload[:hook].to_s,
                'spree.hook.handler_count' => payload[:handler_count]
              }
            end
          ),

          'dispatch.spree_events' => SpanSubscriber.new(
            tracer: tracer,
            name: ->(payload) { "#{payload[:event_name]} dispatch" },
            attributes: lambda do |payload|
              {
                'spree.event.name' => payload[:event_name],
                'spree.event.subscriber' => payload[:subscriber],
                'spree.event.async' => payload[:async] == true
              }
            end
          ),

          'deliver.spree_webhooks' => SpanSubscriber.new(
            tracer: tracer,
            name: ->(payload) { "spree.webhook.deliver #{payload[:event_name]}" },
            kind: ->(_payload) { :client },
            attributes: lambda do |payload|
              {
                'spree.webhook.event' => payload[:event_name],
                'server.address' => payload[:url_host],
                'http.response.status_code' => payload[:response_code],
                'spree.webhook.error_type' => payload[:error_type]
              }
            end,
            error: lambda do |payload|
              next payload[:error_type] if payload[:error_type]
              next "HTTP #{payload[:response_code]}" if payload[:response_code].to_i >= 400

              nil
            end
          ),

          'gateway.spree_payments' => SpanSubscriber.new(
            tracer: tracer,
            name: ->(payload) { "spree.gateway.#{payload[:action]}" },
            kind: ->(_payload) { :client },
            attributes: lambda do |payload|
              {
                'spree.gateway.action' => payload[:action],
                'spree.gateway.payment_method_type' => payload[:payment_method_type]
              }
            end
          )
        }
      end

      # Spree domain events ('order.placed' and friends, published as
      # '<name>.spree' with an intentionally empty instrumented block) wrap no
      # work — they surface as span events on the current span, never as
      # spans. Payloads are deliberately excluded: only the name and event id
      # are attached.
      def domain_event_subscription
        ActiveSupport::Notifications.subscribe(/\.spree$/) do |*args|
          event = args.last[:event]
          next unless event

          ::OpenTelemetry::Trace.current_span.add_event(
            "spree.event #{event.name}",
            attributes: { 'spree.event.id' => event.id.to_s }
          )
        end
      end
    end
  end
end
