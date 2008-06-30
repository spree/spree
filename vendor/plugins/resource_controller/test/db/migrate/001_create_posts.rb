class CreatePosts < ActiveRecord::Migration
  def self.up
    create_table :posts do |t|
      t.column :title, :string, :default => ''
      t.column :body, :text, :default => ''
    end
  end

  def self.down
    drop_table :posts
  end
end
