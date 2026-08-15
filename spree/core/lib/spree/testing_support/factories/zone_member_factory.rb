FactoryBot.define do
  # Defunct alongside :zone — a member no longer points at a country or state
  # record, so it carries only the zone it belongs to.
  factory :zone_member, class: Spree::ZoneMember do
    zone { |member| member.association(:zone) }
  end
end
