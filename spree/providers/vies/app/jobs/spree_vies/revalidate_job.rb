module SpreeVies
  # Queues a check for every EU VAT number {Validator.due_for_check} returns.
  # Run daily — `spree_vies:revalidate`, or a recurring job.
  #
  # Leaves each verdict as it is while its check is queued: the last answer is
  # still the best one there is, and marking the number pending would hide it.
  #
  # Checks are spread out at {SpreeVies.revalidations_per_minute}, so a large
  # backlog doesn't reach VIES all at once.
  class RevalidateJob < Spree::BaseJob
    include ActiveJob::Continuable

    queue_as Spree.queues.tax_identifiers

    def perform
      step :queue_checks
    end

    private

    def queue_checks(step)
      SpreeVies::Validator.due_for_check.find_each(start: step.cursor).each_with_index do |tax_identifier, index|
        delay = (index / SpreeVies.revalidations_per_minute).minutes
        Spree::TaxIdentifiers::ValidateJob.set(wait: delay).perform_later(tax_identifier.id)
        step.advance! from: tax_identifier.id
      end
    end
  end
end
