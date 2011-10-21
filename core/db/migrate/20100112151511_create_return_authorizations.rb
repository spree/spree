class CreateReturnAuthorizations < ActiveRecord::Migration
  def self.up
    create_table :return_authorizations do |t|
      t.string :number, :state
      t.decimal :amount, :precision => 8, :scale => 2, :default => 0.0, :null => false
      t.references :order
      t.text :reason

      t.timestamps
    end
  end

  def self.down
    drop_table :return_authorizations
  end
end
