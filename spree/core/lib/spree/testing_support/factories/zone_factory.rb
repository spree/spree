# Migration-only shell (see Spree::Zone) — used solely by the 5.6→6.0
# data-migration specs to build legacy rows.
FactoryBot.define do
  factory :zone, class: Spree::Zone do
    name        { generate(:random_string) }
    description { generate(:random_string) }
  end
end
