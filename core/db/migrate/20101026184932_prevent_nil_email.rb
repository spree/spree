class PreventNilEmail < ActiveRecord::Migration
  def self.up
    execute("update orders set email = 'guest@example.com' where email is null")
    execute("update orders set email = 'guest@example.com' where email = ''")
  end

  def self.down
  end
end
