class CreateProjects < ActiveRecord::Migration
  def self.up
    create_table :projects do |t|
      t.column :title, :string
    end
  end

  def self.down
    drop_table :projects
  end
end
