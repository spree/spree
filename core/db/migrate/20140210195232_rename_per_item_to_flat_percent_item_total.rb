class RenamePerItemToFlatPercentItemTotal < ActiveRecord::Migration
  def change
	Spree::Calculator.where("type='Spree::Calculator::PerItem'").update_all("type='Spree::Calculator::FlatPercentItemTotal'")
	Spree::Preference.where("`key` like 'spree/calculator/per_item/%'").each do |p|
		p.key = p.key.gsub(/per_item/, 'flat_percent_item_total')
		p.save!
	end
	Spree::Calculator.where("type='Spree::Calculator::FreeShipping'").each do |c|
		pa = Spree::Promotion::Actions::CreateAdjustment.where(:promotion_id => c.calculable_id).first
		pa.type = "Spree::Promotion::Actions::FreeShipping"
		pa.save!
	end	
  end
end
