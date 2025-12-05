# frozen_string_literal: true

module Spree
  module Events
    # Job for executing subscribers asynchronously.
    #
    # When subscribers are configured to run async (the default),
    # this job is enqueued to handle the event processing in the background.
    #
    # @example Direct usage (typically called by the adapter)
    #   Spree::Events::SubscriberJob.perform_later(
    #     'MySubscriber',
    #     { name: 'order.complete', payload: {...}, ... }
    #   )
    #
    class SubscriberJob < Spree::BaseJob
      queue_as Spree.queues.events

      # Retry configuration
      retry_on StandardError, wait: :polynomially_longer, attempts: 3

      discard_on ActiveJob::DeserializationError do |job, error|
        Rails.error.report(error, context: {
          subscriber: job.arguments.first,
          event: job.arguments.second
        })
      end

      # @param subscriber_class_name [String] The subscriber class name
      # @param event_hash [Hash] The event data as a hash
      def perform(subscriber_class_name, event_hash)
        subscriber_class = subscriber_class_name.constantize
        event = reconstruct_event(event_hash)

        if subscriber_class < Spree::Subscriber
          subscriber_class.new.call(event)
        elsif subscriber_class.respond_to?(:call)
          subscriber_class.call(event)
        else
          raise ArgumentError, "#{subscriber_class_name} is not a valid subscriber"
        end
      rescue NameError => e
        Rails.error.report(e, context: {
          subscriber: subscriber_class_name,
          event_name: event_hash[:name] || event_hash['name']
        })
        raise
      end

      private

      def reconstruct_event(event_hash)
        event_hash = event_hash.deep_symbolize_keys
        Spree::Event.new(
          name: event_hash[:name],
          payload: event_hash[:payload],
          metadata: event_hash[:metadata]
        )
      end
    end
  end
end
