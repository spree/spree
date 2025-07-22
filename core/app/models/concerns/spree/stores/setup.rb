module Spree
  module Stores
    module Setup
      extend ActiveSupport::Concern

      def setup_task_done?(task)
        case task
        when :setup_payment_method
          payment_method_setup?
        when :setup_taxes_collection
          Spree::TaxRate.any?
        when :add_products
          products.any?
        when :set_customer_support_email
          customer_support_email.present?
        end
      end

      def setup_tasks_total
        @setup_tasks_total = setup_tasks_list.count
      end

      def setup_tasks_list
        return [] if deleted?

        @setup_tasks_list = []
        @setup_tasks_list << :setup_payment_method
        @setup_tasks_list << :add_products
        @setup_tasks_list << :set_customer_support_email
        @setup_tasks_list << :setup_taxes_collection

        @setup_tasks_list
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
    end
  end
end
