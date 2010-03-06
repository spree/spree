class FixByPopularity < ActiveRecord::Migration
  def self.up
    ProductScope.all.each do |s| 
      s.update_attribute(:name, "descend_by_popularity") if "by_popularity" == s.name
    end
  end

  def self.down
  end
end
