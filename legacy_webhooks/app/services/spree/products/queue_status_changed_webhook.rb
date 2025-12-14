module Spree
  module Products
    class QueueStatusChangedWebhook
      def self.call(ids:, event:)
        return false if ids.blank? || event.blank?

        # for ActiveJob 7.1+
        if ActiveJob.respond_to?(:perform_all_later)
          jobs = ids.map { |id| Spree::Products::QueueStatusChangedWebhookJob.new(id, event) }
          ActiveJob.perform_all_later(jobs)
        else
          ids.each { |id| Spree::Products::QueueStatusChangedWebhookJob.perform_later(id, event) }
        end
      end
    end
  end
end
