class CreateOrganicSubstances < ActiveRecord::Migration
  def self.up
    create_table :organic_substances do |t|
      t.column :type, :string
    end
  end

  def self.down
    drop_table :organic_substances
  end
end
