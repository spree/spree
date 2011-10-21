class RemoveNumberAndCvvFromCredicard < ActiveRecord::Migration
  def self.up
    remove_column :creditcards, :number
    remove_column :creditcards, :verification_value
  end

  def self.down
    add_column :creditcards, :verification_value, :text
    add_column :creditcards, :number, :text
  end
end
