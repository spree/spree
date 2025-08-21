class FixUniqueIndexOnSpreeOrderPromotions < ActiveRecord::Migration[7.2]
  def change
    drop_index :spree_order_promotions, name: 'index_spree_order_promotions_on_promotion_id_and_order_id'

    # Remove duplicate records before adding unique index
    duplicates = execute(<<~SQL)
      SELECT promotion_id, order_id, MIN(id) as keep_id
      FROM spree_order_promotions
      GROUP BY promotion_id, order_id
      HAVING COUNT(*) > 1
    SQL

    duplicates.each do |row|
      execute(<<~SQL)
        DELETE FROM spree_order_promotions
        WHERE promotion_id = #{row['promotion_id']}
        AND order_id = #{row['order_id']}
        AND id != #{row['keep_id']}
      SQL
    end

    add_index :spree_order_promotions, [:promotion_id, :order_id], unique: true, name: 'index_spree_order_promotions_on_promotion_id_and_order_id'
  end
end
