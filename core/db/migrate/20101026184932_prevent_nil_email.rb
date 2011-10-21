class PreventNilEmail < ActiveRecord::Migration
  def self.up
    execute("UPDATE orders SET email = 'guest@example.com' WHERE email IS NULL")
    execute("UPDATE orders SET email = 'guest@example.com' WHERE email = ''")
  end

  def self.down
  end
end
