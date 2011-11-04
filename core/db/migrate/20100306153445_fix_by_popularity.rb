# Legacy table support
class ProductScope < ActiveRecord::Base; end;

class FixByPopularity < ActiveRecord::Migration
  def self.up
    ProductScope.where(:name => 'by_popularity').update_all(:name => 'descend_by_popularity')
  end

  def self.down
    ProductScope.where(:name => 'descend_by_popularity').update_all(:name => 'by_popularity')
  end
end
