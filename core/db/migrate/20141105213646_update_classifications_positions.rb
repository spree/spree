class UpdateClassificationsPositions < ActiveRecord::Migration
  def up
    Spree::Taxon.each do |taxon|
      taxon.classifications.each_with_index do |c12n, i|
        c12n.set_list_position(i)
      end
    end
  end
end
