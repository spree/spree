class PreventNilEmail < ActiveRecord::Migration
  def up
    execute "UPDATE orders SET email = 'guest@example.com' WHERE email IS NULL"
    execute "UPDATE orders SET email = 'guest@example.com' WHERE email = ''"
  end

  def down
  end
end
