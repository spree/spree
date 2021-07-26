class AddUniqueIndexOnPropertyIdAndProductIdToProductProperties < ActiveRecord::Migration[5.2]
  def up
    klass   = Spree::ProductProperty
    columns = %w[property_id product_id]

    unless index_exists?(klass.table_name, columns)
      scope   = klass.unscoped

      say "Find duplicate #{klass} records"
      duplicates = scope.
        select((columns + %w[COUNT(*)]).join(',')).
        group("#{columns.join(',')}").
        having('COUNT(*) > 1').
        map { |row| row.attributes.slice(*columns) }

      say "Delete all but the oldest duplicate #{klass} record"
      duplicates.each do |conditions|
        scope.where(conditions).order(:created_at).drop(1).each(&:destroy)
      end

      say "Add unique index to #{klass.table_name} for #{columns.inspect}"
      add_index klass.table_name, columns, unique: true
    end
  end

  def down
    remove_index :spree_product_properties, [:property_id, :product_id]
  end
end
