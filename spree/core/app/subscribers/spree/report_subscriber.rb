# frozen_string_literal: true

module Spree
  # Handles Report lifecycle events.
  #
  # This subscriber replaces the following callbacks in Spree::Report:
  # - after_commit :generate_async, on: :create
  #
  # When a report is created, this subscriber triggers the async generation job.
  #
  # We use async: false because this subscriber just queues a background job,
  # so there's no benefit to running the subscriber itself asynchronously.
  #
  class ReportSubscriber < Spree::Subscriber
    subscribes_to 'report.created', async: false

    on 'report.created', :generate_report_async

    def generate_report_async(event)
      report_id = event.payload['id']
      return unless report_id

      Spree::Reports::GenerateJob.perform_later(report_id)
    end
  end
end
