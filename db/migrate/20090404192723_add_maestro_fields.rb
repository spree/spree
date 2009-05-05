class AddMaestroFields < ActiveRecord::Migration
  def self.up
    add_column :creditcards, :start_month , :string
    add_column :creditcards, :start_year,   :string
    add_column :creditcards, :issue_number, :string
  end

  def self.down
    remove_columns :creditcards, :start_month, :start_year, :issue_number
  end
end

