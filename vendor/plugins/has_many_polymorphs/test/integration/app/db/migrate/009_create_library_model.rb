class CreateLibraryModel < ActiveRecord::Migration
  def self.up
    create_table :library_models do |t|
      t.column :name, :string
    end
  end

  def self.down
    drop_table :library_models
  end
end
