class AddUniqueIndexToSpreePromotionRules < ActiveRecord::Migration[7.2]
  def up
    # Remove duplicate rules (same type within the same promotion),
    # keeping the oldest record. Mirrors the
    # `validates :type, uniqueness: { scope: :promotion_id }` model
    # constraint at the DB level so concurrent writes can't race past
    # the validation.
    if ActiveRecord::Base.connection.adapter_name == 'Mysql2'
      execute <<-SQL
        DELETE FROM spree_promotion_rules
        WHERE id NOT IN (
          SELECT min_id FROM (
            SELECT MIN(id) AS min_id
            FROM spree_promotion_rules
            GROUP BY promotion_id, type
          ) AS keeper_ids
        )
      SQL
    else
      execute <<-SQL
        DELETE FROM spree_promotion_rules
        WHERE id NOT IN (
          SELECT MIN(id)
          FROM spree_promotion_rules
          GROUP BY promotion_id, type
        )
      SQL
    end

    add_index :spree_promotion_rules, [:promotion_id, :type], unique: true,
              name: 'index_spree_promotion_rules_on_promotion_id_and_type'
  end

  def down
    remove_index :spree_promotion_rules, name: 'index_spree_promotion_rules_on_promotion_id_and_type', if_exists: true
  end
end
