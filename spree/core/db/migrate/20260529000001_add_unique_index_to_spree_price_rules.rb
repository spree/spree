class AddUniqueIndexToSpreePriceRules < ActiveRecord::Migration[7.2]
  def up
    # Remove duplicate rules (same type within the same price list),
    # keeping the oldest record. Mirrors the
    # `validates :type, uniqueness: { scope: :price_list_id }` model
    # constraint at the DB level so concurrent writes can't race past
    # the validation.
    if ActiveRecord::Base.connection.adapter_name == 'Mysql2'
      execute <<-SQL
        DELETE FROM spree_price_rules
        WHERE id NOT IN (
          SELECT min_id FROM (
            SELECT MIN(id) AS min_id
            FROM spree_price_rules
            GROUP BY price_list_id, type
          ) AS keeper_ids
        )
      SQL
    else
      execute <<-SQL
        DELETE FROM spree_price_rules
        WHERE id NOT IN (
          SELECT MIN(id)
          FROM spree_price_rules
          GROUP BY price_list_id, type
        )
      SQL
    end

    remove_index :spree_price_rules, [:price_list_id, :type], if_exists: true

    add_index :spree_price_rules, [:price_list_id, :type], unique: true,
              name: 'index_spree_price_rules_on_price_list_id_and_type', if_not_exists: true
  end

  def down
    remove_index :spree_price_rules, name: 'index_spree_price_rules_on_price_list_id_and_type', if_exists: true

    add_index :spree_price_rules, [:price_list_id, :type], if_not_exists: true
  end
end
