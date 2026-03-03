# frozen_string_literal: true

module Spree
  # Handles Export lifecycle events.
  #
  # This subscriber replaces the following callbacks in Spree::Export:
  # - after_commit :generate_async, on: :create
  #
  # When an export is created, this subscriber triggers the async generation job.
  #
  # We use async: false because this subscriber just queues a background job,
  # so there's no benefit to running the subscriber itself asynchronously.
  #
  class ExportSubscriber < Spree::Subscriber
    subscribes_to 'export.created', async: false

    on 'export.created', :generate_export_async

    def generate_export_async(event)
      export = Spree::Export.find_by_prefix_id(event.payload['id'])
      return unless export

      Spree::Exports::GenerateJob.perform_later(export.id)
    end
  end
end
