FactoryGirl.define do
  factory :global_zone, :class => Zone do
    name 'GlobalZone'
    description { Faker::Lorem.sentence }
    zone_members do |proxy|
      zone = proxy.instance_eval{@instance}
      Country.all.map{|c| ZoneMember.create({:zoneable => c, :zone => zone})}
    end
  end

  factory :zone do
    name { Faker::Lorem.words }
    description { Faker::Lorem.sentence }
    zone_members do
      [ZoneMember.create(:zoneable => Factory(:country) )]
    end
  end
end