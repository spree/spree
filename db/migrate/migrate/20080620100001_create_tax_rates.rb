class CreateTaxRates < ActiveRecord::Migration
  def self.up
    create_table :tax_rates do |t|
      t.references :state
      t.decimal :amount, :precision => 8, :scale => 4
      t.timestamps
    end
  end

  def self.down
    drop_table :tax_rates
  end
end
