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

        transient do
          # By default, only include a few countries for speed
          # Set to true if you need all countries in the zone
          include_all_countries { false }
        end

        zone_members do |proxy|
          zone = proxy.instance_eval { @instance }

          if proxy.include_all_countries
            Spree::Country.all.map do |country|
              Spree::ZoneMember.where(zoneable: country, zone: zone).first_or_create
            end
          else
            # Just include the default country and a couple others for speed
            countries = [
              Spree::Country.find_by(iso: 'US') || create(:country, iso: 'US', name: 'United States'),
              Spree::Country.find_by(iso: 'CA') || create(:country, iso: 'CA', name: 'Canada')
            ].compact.uniq

            countries.map do |country|
              Spree::ZoneMember.where(zoneable: country, zone: zone).first_or_create
            end
          end
        end
      end
    end
  end
end
