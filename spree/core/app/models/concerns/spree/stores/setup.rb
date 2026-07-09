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
        when :setup_storefront
          storefront_setup?
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
        @setup_tasks_list << :setup_storefront

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

      # A storefront counts as set up once an active publishable key has actually
      # authenticated a Store API request and a storefront is connected.
      def storefront_setup?
        storefront_publishable_key_used? && storefront_connected?
      end

      def storefront_publishable_key_used?
        api_keys.active.publishable.where.not(last_used_at: nil).exists?
      end

      # A non-loopback allowed origin (web storefronts) or an explicit storefront
      # URL (mobile apps and other clients that don't need CORS) both count as a
      # connected storefront; the `http://localhost` origin seeded on install
      # doesn't.
      def storefront_connected?
        storefront_origin_added? || preferred_storefront_url.present?
      end

      def storefront_origin_added?
        allowed_origins.reject(&:loopback?).any?
      end
    end
  end
end
