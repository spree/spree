Factory.sequence(:zone_sequence) {|n| "Zone ##{n}"}

Factory.define(:global_zone, :class => Zone) do |record|
  record.name "GlobalZone"
  record.description { Faker::Lorem.sentence }
  record.zone_members {|proxy|
    zone = proxy.instance_eval{@instance}
    Country.find(:all).map{|c| ZoneMember.create({:zoneable => c, :zone => zone})}
  }
end
