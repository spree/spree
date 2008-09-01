class CreateOptions < ActiveRecord::Migration
  def self.up
    create_table :options do |t|
      t.references :product
      t.references :account
      t.string :title
    end
  end

  def self.down
    drop_table :options
  end
end
