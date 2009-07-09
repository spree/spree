class MigrateImagesToVariants < ActiveRecord::Migration
  def self.up
		Image.all.each do |i|
			i.viewable = i.viewable.variants? ? i.viewable.variants[0] : i.viewable.variant
			i.save!
		end
  end

  def self.down
  end
end
