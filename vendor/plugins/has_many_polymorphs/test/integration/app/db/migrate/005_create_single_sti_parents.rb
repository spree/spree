class CreateSingleStiParents < ActiveRecord::Migration
  def self.up
    create_table :single_sti_parents do |t|
      t.column :name, :string
    end
  end

  def self.down
    drop_table :single_sti_parents
  end
end
