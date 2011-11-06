class CreateMailMethods < ActiveRecord::Migration
  def change
    create_table :mail_methods do |t|
      t.string :environment
      t.boolean :active, :default => true

      t.timestamps
    end
  end
end
