module Spree
  class ShippingMethod < ActiveRecord::Base
    include Spree::Core::CalculatedAdjustments
    DISPLAY = [:both, :front_end, :back_end]

    default_scope where(:deleted_at => nil)

    has_many :shipments
    validates :name, :zone, :presence => true

    belongs_to :shipping_category
    belongs_to :zone

    attr_accessible :name, :zone_id, :display_on, :shipping_category_id,
                    :match_none, :match_one, :match_all, :tracking_url

    def adjustment_label
      I18n.t(:shipping)
    end
  end
end
