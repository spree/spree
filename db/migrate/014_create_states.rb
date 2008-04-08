class CreateStates< ActiveRecord::Migration
  def self.up
    create_table :states do |t|
      t.column :name, :string
      t.column :abbr, :string
      t.column :country_id, :integer
    end
  end

  def self.down
    drop_table :states
  end
end