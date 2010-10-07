class CreateMailMethods < ActiveRecord::Migration
  def self.up
    create_table :mail_methods do |t|
      t.string :environment
      t.boolean :active, :default => true
      t.timestamps
    end
  end

  def self.down
  end
end
