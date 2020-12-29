FactoryBot.define do
  factory :zone, class: Spree::Zone do
    name        { generate(:random_string) }
    description { generate(:random_string) }

    factory :zone_with_country do
      kind { :country }

      zone_members do |proxy|
        zone = proxy.instance_eval { @instance }

        [Spree::ZoneMember.create(zoneable: create(:country), zone: zone)]
      end

      factory :global_zone, class: Spree::Zone do
        sequence(:name) { |n| "GlobalZone_#{n}" }

        zone_members do |proxy|
          zone = proxy.instance_eval { @instance }

          Spree::Country.all.map do |country|
            Spree::ZoneMember.where(zoneable: country, zone: zone).first_or_create
          end
        end
      end
    end
  end
end
