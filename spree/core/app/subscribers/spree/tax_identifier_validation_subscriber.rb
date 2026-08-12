# frozen_string_literal: true

module Spree
  # Asks the registry whether a buyer's tax number is real, whenever that number
  # changes.
  #
  # Runs synchronously: the row has to read +pending+ in the same request that
  # wrote it, so the buyer sees "we're checking this" rather than a blank verdict
  # that fills in later. The check itself is the background job.
  class TaxIdentifierValidationSubscriber < Spree::Subscriber
    subscribes_to 'tax_identifier.number_changed', async: false

    def call(event)
      identifier = Spree::TaxIdentifier.find_by_prefix_id(event.payload['id'])
      return if identifier.nil?

      # Nothing to ask when no validator is registered for this kind — a stock
      # install registers none — and an order's snapshot is never re-checked.
      return unless identifier.validatable?

      # The row is already marked pending by the write that published this;
      # queueing the registry call is all that is left.
      Spree::TaxIdentifiers::ValidateJob.perform_later(identifier.id)
    end
  end
end
