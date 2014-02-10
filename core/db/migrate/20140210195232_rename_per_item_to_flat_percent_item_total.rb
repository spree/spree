class RenamePerItemToFlatPercentItemTotal < ActiveRecord::Migration
  def change
	Spree::Calculator.where("type='Spree::Calculator::PerItem'").update_all("type='Spree::Calculator::FlatPercentItemTotal'")
	Spree::Preference.where("`key` like 'spree/calculator/per_item/%'").each do |p|
		p.key = p.key.gsub(/per_item/, 'flat_percent_item_total')
		p.save!
	end
  end
end
