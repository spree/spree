class RefactorAdjustments < ActiveRecord::Migration
  def up
    change_table :adjustments do |t|
      t.boolean :mandatory
      t.boolean :frozen
      t.rename :adjustment_source_id, :source_id
      t.rename :adjustment_source_type, :source_type
      t.references :originator
      t.string :originator_type
      t.remove :type
      t.rename :description, :label
      t.remove :position
    end
  end

  def down
    change_table :adjustments do |t|
      t.integer :position
      t.rename :label, :description
      t.string :type
      t.remove :originator_type
      t.remove :originator_id
      t.rename :source_type, :adjustment_source_type
      t.rename :source_id, :adjustment_source_id
      t.remove :frozen
      t.remove :mandatory
    end
  end
end
