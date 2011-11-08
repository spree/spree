class FixByPopularity < ActiveRecord::Migration
  def up
    execute("UPDATE product_scopes SET name='descend_by_popularity' WHERE name='by_popularity'")
  end

  def down
    execute("UPDATE product_scopes SET name='by_popularity' WHERE name='descend_by_popularity'")
  end
end
