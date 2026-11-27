module Spree
  # Writes an order's timeline from the events its records publish
  # (docs/plans/6.1-order-timeline.md). Which events count, and what each
  # records, is `Spree.order_activity_kinds`.
  #
  # Synchronous, so the entry exists by the time the request that made it
  # returns. An event published inside its step's transaction writes inside
  # it too, so a step that rolls back leaves nothing. The write takes its own
  # savepoint: a failure is reported and never fails the step.
  class OrderActivitySubscriber < Spree::Subscriber
    # Every event, because an extension can register a kind after this
    # subscriber is set up; the registry decides which ones are written.
    subscribes_to '*', async: false

    def handle(event)
      kind = Spree.order_activity_kinds[event.name]
      return unless kind

      # The builder reads the database too, so it runs inside the savepoint:
      # a failed query must not abort the step's own transaction.
      ApplicationRecord.transaction(requires_new: true) do
        # One entry, or several: a placement also records what checkout
        # settled, and a split checkout's payment shows on each order.
        Array.wrap(kind.builder.call(event)).compact.each do |attributes|
          # A draft or a cart has no timeline to show it on.
          next if attributes[:order]&.completed_at.nil?

          entry_kind = attributes[:kind] || event.name
          Spree::OrderActivity.create!(
            order: attributes[:order],
            order_change: attributes[:order_change],
            details: attributes[:details].presence,
            kind: entry_kind,
            category: Spree.order_activity_kinds[entry_kind]&.category || kind.category,
            actor: event.actor,
            created_at: event.created_at
          )
        end
      end
    rescue StandardError => e
      Rails.error.report(e, source: 'spree.order_activities', context: { event: event.name })
    end
  end
end
