FactoryGirl.define do
  factory :global_zone, class: Spree::Zone do
    name 'GlobalZone'
    description { generate(:random_string) }
    zone_members do |proxy|
      zone = proxy.instance_eval { @instance }
      Spree::Country.all.map do |c|
        zone_member = Spree::ZoneMember.create(zoneable: c, zone: zone)
      end
    end
  end

  factory :zone, class: Spree::Zone do
    name { generate(:random_string) }
    description { generate(:random_string) }

    factory :zone_with_country do
      zone_members do |proxy|
        zone = proxy.instance_eval { @instance }
        country = create(:country)
        [Spree::ZoneMember.create(zoneable: country, zone: zone)]
      end
    end
  end
end
