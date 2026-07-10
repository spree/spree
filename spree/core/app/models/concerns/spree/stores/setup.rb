module Spree
  module Stores
    module Setup
      extend ActiveSupport::Concern

      # The evaluated Getting Started checklist for this store, in display
      # order — what the Admin API serializes and every other setup method
      # derives from. Memoized per instance: the dashboard evaluates the
      # checklist several times per render (sidebar badge, progress bar, task
      # list) and each done-check costs a query.
      #
      # @return [Array<Spree::SetupTask>]
      def setup_tasks
        return [] if deleted?

        @setup_tasks ||= Spree.store_setup_tasks.for(self).map do |definition|
          Spree::SetupTask.new(name: definition.key.to_s, done: definition.done?(self))
        end
      end

      def setup_task_done?(task)
        setup_tasks.find { |t| t.name == task.to_s }&.done
      end

      def setup_tasks_list
        setup_tasks.map { |task| task.name.to_sym }
      end

      def setup_tasks_total
        setup_tasks.size
      end

      def setup_tasks_done
        setup_tasks.count(&:done)
      end

      def setup_completed?
        setup_tasks_done == setup_tasks_total
      end

      def setup_percentage
        return 0 if setup_tasks_total.zero?

        (setup_tasks_done / setup_tasks_total.to_f * 100).to_i
      end

      def payment_method_setup?
        payment_methods.active.where.not(type: Spree::PaymentMethod::StoreCredit.to_s).any?
      end

      # A storefront counts as set up once the merchant has saved the storefront
      # URL (entered manually or backfilled by the Vercel callback).
      def storefront_setup?
        preferred_storefront_url.present?
      end
    end
  end
end
