module SpreeVies
  # Queues a check for every EU VAT number {Validator.due_for_check} returns.
  # Run daily — `spree_vies:revalidate`, or a recurring job.
  #
  # Leaves each verdict as it is while its check is queued: the last answer is
  # still the best one there is, and marking the number pending would hide it.
  #
  # Checks are spread out evenly at {SpreeVies.revalidations_per_minute}, so a
  # large backlog doesn't reach VIES all at once. The job's progress records the
  # next number and when its check is due, so a run that is interrupted carries
  # on after the checks it already queued, or from now if those are past.
  class RevalidateJob < Spree::BaseJob
    include ActiveJob::Continuable

    queue_as Spree.queues.tax_identifiers

    def perform
      step :queue_checks
    end

    private

    # The cursor is saved through the queue adapter's JSON, so it holds only an
    # id and an epoch time: `[next_id, next_release_at]`.
    def queue_checks(step)
      next_id, next_release_at = step.cursor
      release_at = [Time.current, next_release_at && Time.zone.at(next_release_at)].compact.max
      interval = 60.0 / SpreeVies.revalidations_per_minute

      SpreeVies::Validator.due_for_check.find_each(start: next_id) do |tax_identifier|
        Spree::TaxIdentifiers::ValidateJob.set(wait_until: release_at).perform_later(tax_identifier.id)

        release_at += interval
        step.set! [tax_identifier.id.succ, release_at.to_f]
      end
    end
  end
end
