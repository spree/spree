module Spree
  module Stores
    module Setup
      extend ActiveSupport::Concern

      def setup_task_done?(task)
        Spree.store_setup_tasks.find(task)&.done?(self)
      end

      # The evaluated Getting Started checklist for this store, in display
      # order — what the Admin API serializes.
      #
      # @return [Array<Spree::SetupTask>]
      def setup_tasks
        Spree.store_setup_tasks.for(self).map do |task|
          Spree::SetupTask.new(name: task.key.to_s, done: task.done?(self))
        end
      end

      def setup_tasks_total
        @setup_tasks_total = setup_tasks_list.count
      end

      def setup_tasks_list
        return [] if deleted?

        Spree.store_setup_tasks.for(self).map(&:key)
      end

      def setup_tasks_done
        @setup_tasks_done = setup_tasks_list.select { |task| setup_task_done?(task) }.count
      end

      def setup_completed?
        @setup_completed ||= setup_tasks_done == setup_tasks_total
      end

      def setup_percentage
        @setup_percentage ||= (setup_tasks_done / setup_tasks_total.to_f * 100).to_i
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
