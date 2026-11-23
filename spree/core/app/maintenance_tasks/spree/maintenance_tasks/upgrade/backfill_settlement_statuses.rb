module Spree
  module MaintenanceTasks
    module Upgrade
      # Capture events and refunds gained a status in a 6.0 patch release (a
      # gateway may now answer that it is still waiting on its provider), added
      # empty by the migration. Every row written before then is money that
      # moved, so it is marked completed here. Walks payments, the one record
      # both tables hang from, so the run has a single cursor.
      class BackfillSettlementStatuses < Spree::MaintenanceTask
        supports_dry_run
        collection_batch_size 1_000

        def collection
          capture_event_payment_ids = Spree::PaymentCaptureEvent.where(status: nil).select(:payment_id)
          refund_payment_ids = Spree::Refund.where(status: nil).select(:payment_id)

          Spree::Payment.unscoped.
            where(id: capture_event_payment_ids).
            or(Spree::Payment.unscoped.where(id: refund_payment_ids)).
            order(:id)
        end

        def process(payment)
          capture_events = Spree::PaymentCaptureEvent.where(payment_id: payment.id, status: nil)
          refunds = Spree::Refund.where(payment_id: payment.id, status: nil)

          if dry_run?
            tally(:capture_events_would_complete, capture_events.count)
            tally(:refunds_would_complete, refunds.count)
            return
          end

          now = Time.current
          tally(:capture_events_completed, capture_events.update_all(status: 'completed', updated_at: now))
          tally(:refunds_completed, refunds.update_all(status: 'completed', updated_at: now))
        end
      end
    end
  end
end
