# Legacy table support
class ProductScope < ActiveRecord::Base; end;

class FixByPopularity < ActiveRecord::Migration
  def self.up
    ProductScope.update_all("name='descend_by_popularity'", "name='by_popularity'")
  end

  def self.down
    ProductScope.update_all("name='by_popularity'", "name='descend_by_popularity'")
  end
end
