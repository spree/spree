module Spree
  # Migration-only shell, removed in Spree 6.1 with {Spree::Zone}.
  class ZoneMember < Spree.base_class
    # No zoneable association: countries and states are reference data in 6.0,
    # so the type and id columns are plain values resolved against the legacy
    # tables by the data-migration tasks.
    belongs_to :zone, class_name: 'Spree::Zone', inverse_of: :zone_members

  end
end
