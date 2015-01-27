class MovePromotionCodesToSpreePromotionCode < ActiveRecord::Migration
  def change
    Spree::Promotion.find_each do |promo|
      promo.codes.create! value: promo.code if promo.code.present?
    end
  end
end
