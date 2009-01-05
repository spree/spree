class ConvertCredticardNumberToText < ActiveRecord::Migration
  def self.up
    change_column :creditcards, :number, :text
    change_column :creditcards, :verification_value, :text
  end

  def self.down
    change_column :creditcards, :number, :string
    change_column :creditcards, :verification_value, :string
  end
end
