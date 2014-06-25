class UniqueShippingMethodCategories < ActiveRecord::Migration
  def change
    klass   = Spree::ShippingMethodCategory
    columns = %w[shipping_category_id shipping_method_id]

    say "Find duplicate #{klass} records"
    duplicates = klass.
      select((columns + %w[COUNT(*)]).join(',')).
      group(columns.join(',')).
      having('COUNT(*) > 1').
      map { |row| row.attributes.slice(*columns) }

    say "Delete all but the oldest duplicate #{klass} record"
    duplicates.each do |conditions|
      klass.where(conditions).order(:created_at).drop(1).each(&:destroy)
    end

    say "Add unique index to #{klass.table_name} for #{columns.inspect}"
    add_index klass.table_name, columns, unique: true, name: 'unique_spree_shipping_method_categories'

    say "Remove redundant simple index on #{klass.table_name}"
    remove_index klass.table_name, name: 'index_spree_shipping_method_categories_on_shipping_category_id'
  end
end
