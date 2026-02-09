# This migration comes from spree (originally 20250821211705)
class FixUniqueIndexOnSpreeOrderPromotions < ActiveRecord::Migration[7.2]
  def change
    remove_index :spree_order_promotions, name: 'index_spree_order_promotions_on_promotion_id_and_order_id', if_exists: true

    # Remove duplicate records before adding unique index
    duplicates = Spree::OrderPromotion.select(:promotion_id, :order_id).group(:promotion_id, :order_id).having('COUNT(*) > 1').reorder('').pluck(:promotion_id, :order_id)

    duplicates.each do |duplicate_promotion_id, duplicate_order_id|
      order_promotions = Spree::OrderPromotion.where(promotion_id: duplicate_promotion_id, order_id: duplicate_order_id)

      order_promotions.each_with_index do |order_promotion, index|
        next if index == 0 # Keep the first one unchanged

        order_promotion.destroy
      end
    end

    add_index :spree_order_promotions, [:promotion_id, :order_id], unique: true, name: 'index_spree_order_promotions_on_promotion_id_and_order_id'
  end
end
