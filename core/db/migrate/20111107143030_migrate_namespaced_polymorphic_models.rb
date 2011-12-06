class MigrateNamespacedPolymorphicModels < ActiveRecord::Migration
  def up
    ['spree_payments', 'spree_adjustments', 'spree_log_entries'].each do |table|
      collection = select_all "SELECT * FROM #{table} WHERE source_type NOT LIKE 'Spree::%' AND source_type IS NOT NULL"
      collection.each do |member|
        execute "UPDATE #{table} SET source_type = 'Spree::#{member['source_type']}'"
      end
    end

    adjustments = select_all "SELECT * FROM spree_adjustments WHERE originator_type NOT LIKE 'Spree::%' AND originator_type IS NOT NULL"

    adjustments.each do |adjustment|
      execute "UPDATE spree_adjustments SET originator_type = 'Spree::#{adjustment['originator_type']}'"
    end
  end

  def down
    ['spree_payments', 'spree_adjustments', 'spree_log_entries'].each do |table|
      collection = select_all "SELECT * FROM #{table} WHERE source_type LIKE 'Spree::%'"
      collection.each do |member|
        execute "UPDATE #{table} SET source_type = '#{member['source_type'].gsub('Spree::', '')}'"
      end
    end

    adjustments = select_all "SELECT * FROM spree_adjustments WHERE originator_type LIKE 'Spree::%'"

    adjustments.each do |adjustment|
      execute "UPDATE spree_adjustments SET originator_type = '#{payments['originator_type'].gsub('Spree::', '')}'"
    end
  end
end
