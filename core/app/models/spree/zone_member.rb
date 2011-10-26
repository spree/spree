class Spree::ZoneMember < ActiveRecord::Base
  belongs_to :zone, :class_name => 'Spree::Zone'
  belongs_to :zoneable, :polymorphic => true

  def name
    return nil if zoneable.nil?
    zoneable.name
  end
end
