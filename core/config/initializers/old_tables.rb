#  NOTE: It is safe to remove this initializer once the database has been migrated above the namespace_top_level_models migration.
#
#  This is a hack needed when running under PostgreSQL.  It's needed because certain ActiveRecord::Base
#  calls (table_exists?, etc) will trigger a query such as this:
#
#    PGError: ERROR:  relation "spree_products" does not exist
#    LINE 4:              WHERE a.attrelid = '"spree_products"'::regclass
#                                            ^
#    :             SELECT a.attname, format_type(a.atttypid, a.atttypmod), d.adsrc, a.attnotnull
#                  FROM pg_attribute a LEFT JOIN pg_attrdef d
#                    ON a.attrelid = d.adrelid AND a.attnum = d.adnum
#                 WHERE a.attrelid = '"spree_products"'::regclass
#                   AND a.attnum > 0 AND NOT a.attisdropped
#                 ORDER BY a.attnum
#
#  Some of these calls happen when the model classes are loaded (Spree::Product).  When in the migrations,
#  by the time you call Spree::Product.table_name = 'products', it's too late.  Setting the table names explicitly
#  below was the only way I could get the migrations to run properly.
#
tables = ActiveRecord::Base.connection.tables

if !tables.include?("schema_migrations") or !tables.include?("spree_products")
  Spree::Variant.class_eval do
    set_table_name 'variants'
  end

  Spree::Product.class_eval do
    set_table_name 'products'
  end

  Spree::InventoryUnit.class_eval do
    set_table_name 'inventory_units'
  end

  Spree::Taxon.class_eval do
    set_table_name 'taxons'
  end

  Spree::Shipment.class_eval do
    set_table_name 'shipments'
  end

  Spree::Order.class_eval do
    set_table_name 'orders'
  end

  Spree::Adjustment.class_eval do
    set_table_name 'adjustments'
  end

  Spree::Creditcard.class_eval do
    set_table_name 'creditcards'
  end
else
  puts "NOTE: Initializer #{__FILE__} is no longer needed and can be removed"
end
