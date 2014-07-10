class RecreateSpreeReturnAuthorizations < ActiveRecord::Migration
  def up
    # If the app has any legacy return authorizations then rename the table & columns and leave them there
    # for the spree_legacy_return_authorizations extension to pick up with.
    # Otherwise just drop the tables/columns as they are no longer used in stock spree.  The spree_legacy_return_authorizations
    # extension will recreate these tables for dev environments & etc as needed.
    if Spree::ReturnAuthorization.exists?
      rename_table :spree_return_authorizations, :spree_legacy_return_authorizations
      rename_column :spree_inventory_units, :return_authorization_id, :legacy_return_authorization_id
    else
      drop_table :spree_return_authorizations
      remove_column :spree_inventory_units, :return_authorization_id
    end

    Spree::Adjustment.where(source_type: 'Spree::ReturnAuthorization').update_all(source_type: 'Spree::LegacyReturnAuthorization')

    # For now just recreate the table as it was.  Future changes to the schema (including dropping "amount") will be coming in a
    # separate commit.
    create_table :spree_return_authorizations do |t|
      t.string   "number"
      t.string   "state"
      t.decimal  "amount", precision: 10, scale: 2, default: 0.0, null: false
      t.integer  "order_id"
      t.text     "reason"
      t.datetime "created_at"
      t.datetime "updated_at"
      t.integer  "stock_location_id"
    end

  end

  def down
    drop_table :spree_return_authorizations

    Spree::Adjustment.where(source_type: 'Spree::LegacyReturnAuthorization').update_all(source_type: 'Spree::ReturnAuthorization')

    if table_exists?(:spree_legacy_return_authorizations)
      rename_table :spree_legacy_return_authorizations, :spree_return_authorizations
      rename_column :spree_inventory_units, :legacy_return_authorization_id, :return_authorization_id
    else
      create_table :spree_return_authorizations do |t|
        t.string   "number"
        t.string   "state"
        t.decimal  "amount", precision: 10, scale: 2, default: 0.0, null: false
        t.integer  "order_id"
        t.text     "reason"
        t.datetime "created_at"
        t.datetime "updated_at"
        t.integer  "stock_location_id"
      end
      add_column :spree_inventory_units, :return_authorization_id, :integer, after: :shipment_id
      add_index :spree_inventory_units, :return_authorization_id
    end
  end
end
