class RefactorAdjustments < ActiveRecord::Migration
  def self.up
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

  def self.down
    # no going back
  end
end
