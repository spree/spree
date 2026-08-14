module Spree
  # Migration-only shell, removed in Spree 6.1 with {Spree::Zone}.
  class ZoneMember < Spree.base_class
    belongs_to :zone, class_name: 'Spree::Zone', inverse_of: :zone_members
    belongs_to :zoneable, polymorphic: true

    validates :zone, :zoneable, presence: true
  end
end
