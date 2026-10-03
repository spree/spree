module SpreeVies
  # Queues a check for every EU VAT number {Validator.due_for_check} returns.
  # Run daily — `spree_vies:revalidate`, or a recurring job.
  #
  # Leaves each verdict as it is while its check is queued: the last answer is
  # still the best one there is, and marking the number pending would hide it.
  #
  # Checks are spread out at {SpreeVies.revalidations_per_minute}, so a large
  # backlog doesn't reach VIES all at once. The schedule is saved with the
  # job's progress, so a run that is interrupted and resumed keeps to it.
  class RevalidateJob < Spree::BaseJob
    include ActiveJob::Continuable

    queue_as Spree.queues.tax_identifiers

    def perform
      step :queue_checks
    end

    private

    def queue_checks(step)
      schedule = step.cursor || { next_id: nil, released: 0, started_at: Time.current }

      SpreeVies::Validator.due_for_check.find_each(start: schedule[:next_id]) do |tax_identifier|
        Spree::TaxIdentifiers::ValidateJob.set(wait_until: release_time(schedule)).perform_later(tax_identifier.id)

        schedule = schedule.merge(next_id: tax_identifier.id.succ, released: schedule[:released] + 1)
        step.set! schedule
      end
    end

    def release_time(schedule)
      schedule[:started_at] + (schedule[:released] / SpreeVies.revalidations_per_minute).minutes
    end
  end
end
