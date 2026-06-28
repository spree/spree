namespace :spree do
  namespace :upgrade do
    desc <<~DESC
      Populates +spree_promotions.store_id+ and +spree_payment_methods.store_id+
      from the legacy +spree_promotions_stores+ / +spree_payment_methods_stores+
      join tables. Idempotent — re-running skips records that already have a
      +store_id+.

      Run once after upgrading to Spree 5.6+. Multi-store merchants must install
      +spree_multi_store+ before running; without it, a record shared across
      several stores keeps only one owner (promotions: the earliest
      +spree_promotions_stores+ row by +created_at+; payment methods: the lowest
      +store_id+, since that join has no timestamps) and the other stores lose
      the shared record. Each shared record is logged so the loss is visible.
    DESC
    task populate_single_store_associations: :environment do
      shared = Hash.new(0)

      if ActiveRecord::Base.connection.table_exists?(Spree::StorePromotion.table_name)
        Spree::Promotion.where(store_id: nil).find_each do |promotion|
          store_ids = Spree::StorePromotion.where(promotion_id: promotion.id).order(:created_at).pluck(:store_id)
          next if store_ids.empty?

          if store_ids.size > 1
            shared[:promotions] += 1
            Spree::Deprecation.warn(
              "Promotion #{promotion.id} was shared across #{store_ids.size} stores; " \
              "assigning it to store #{store_ids.first}. Install spree_multi_store to keep sharing."
            )
          end

          promotion.update_column(:store_id, store_ids.first)
        end
      else
        puts "  #{Spree::StorePromotion.table_name} table not found — skipping promotions."
      end

      if ActiveRecord::Base.connection.table_exists?(Spree::StorePaymentMethod.table_name)
        Spree::PaymentMethod.where(store_id: nil).find_each do |payment_method|
          store_ids = Spree::StorePaymentMethod.where(payment_method_id: payment_method.id).order(:store_id).pluck(:store_id)
          next if store_ids.empty?

          if store_ids.size > 1
            shared[:payment_methods] += 1
            Spree::Deprecation.warn(
              "PaymentMethod #{payment_method.id} was shared across #{store_ids.size} stores; " \
              "assigning it to store #{store_ids.first}. Install spree_multi_store to keep sharing."
            )
          end

          payment_method.update_column(:store_id, store_ids.first)
        end
      else
        puts "  #{Spree::StorePaymentMethod.table_name} table not found — skipping payment methods."
      end

      if shared.values.sum.positive?
        puts "  #{shared[:promotions]} promotion(s) and #{shared[:payment_methods]} payment method(s) " \
             "were shared across stores — only the owner store keeps them unless spree_multi_store is installed."
      end
    end
  end
end
