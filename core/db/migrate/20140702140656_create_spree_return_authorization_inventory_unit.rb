class CreateSpreeReturnAuthorizationInventoryUnit < ActiveRecord::Migration
  def up
    create_table :spree_return_authorization_inventory_units do |t|
      t.integer :return_authorization_id
      t.integer :inventory_unit_id
      t.integer :exchange_variant_id
      t.datetime :received_at

      t.timestamps
    end

    execute(<<-SQL)
      insert into spree_return_authorization_inventory_units
        (
          return_authorization_id,
          inventory_unit_id,
          received_at,
          created_at,
          updated_at
        )
      select
        return_authorization_id,
        id,
        case state
          when 'returned' then updated_at
          when 'refunded' then updated_at
          else null
        end,
        created_at,
        '#{Time.now.to_s(:db)}'
      from spree_inventory_units
      where return_authorization_id is not null;
    SQL

    remove_column :spree_inventory_units, :return_authorization_id
  end

  def down
    add_column :spree_inventory_units, :return_authorization_id, :integer, after: :shipment_id

    execute(<<-SQL)
      update spree_inventory_units
      set return_authorization_id = spree_return_authorization_inventory_units.return_authorization_id
      from spree_return_authorization_inventory_units
      where spree_return_authorization_inventory_units.inventory_unit_id = spree_inventory_units.id
    SQL

    add_index :spree_inventory_units, :return_authorization_id, name: "index_spree_inventory_units_on_return_authorization_id"

    drop_table :spree_return_authorization_inventory_units
  end
end
