class CreateComments < ActiveRecord::Migration
  def self.up
    create_table :comments do |t|
      t.column :post_id, :integer
      t.column :author, :string
      t.column :body, :text
    end
  end

  def self.down
    drop_table :comments
  end
end
