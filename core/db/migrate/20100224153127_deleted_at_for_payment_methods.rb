class DeletedAtForPaymentMethods < ActiveRecord::Migration
  def self.up
    change_table :payment_methods do |t|
      t.timestamp :deleted_at, :default => nil
    end
  end

  def self.down
    change_table :payment_methods do |t|
      t.remove :deleted_at
    end
  end
end
