class AddIndexOnPermalinkParentIdAndTaxonomyIdOnSpreeTaxons < ActiveRecord::Migration[5.2]
  def up
    klass   = Spree::Taxon
    columns = %w[permalink parent_id taxonomy_id]

    unless index_exists?(klass.table_name, columns)
      remove_index klass.table_name, columns if index_exists?(klass.table_name, columns)

      say "Find duplicate #{klass} records"
      duplicates = klass.
        select((columns + %w[COUNT(*)]).join(',')).
        group("#{columns.join(',')}").
        having('COUNT(*) > 1').
        map { |row| row.attributes.slice(*columns) }

      say "Delete all but the oldest duplicate #{klass} record"
      duplicates.each do |conditions|
        klass.where(conditions).order(:created_at).drop(1).each(&:destroy)
      end

      duplicates.each do |conditions| puts klass.where(conditions).order(:created_at).drop(1) end

      say "Add unique index to #{klass.table_name} for #{columns.inspect}"
      add_index klass.table_name, columns, unique: true
    end
  end

  def down
    remove_index :spree_taxons, [:permalink, :parent_id, :taxonomy_id]
  end
end
