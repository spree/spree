FactoryBot.define do
  factory :shipping_label, class: Spree::ShippingLabel do
    association :owner, factory: :fulfillment, tracking: nil
    store { owner.store }
    source { 'purchased' }
    status { 'purchased' }
    carrier { 'ups' }
    service { 'Ground' }
    sequence(:tracking_number) { |n| "1Z879E93034683#{n.to_s.rjust(4, '0')}" }
    sequence(:external_id) { |n| "shp_#{n}" }
    cost { 7.25 }
    currency { 'USD' }
    format { 'pdf' }

    trait :uploaded do
      source { 'uploaded' }
      external_id { nil }
    end

    trait :with_file do
      after(:build) do |shipping_label|
        shipping_label.file.attach(
          io: StringIO.new("%PDF-1.4\n%label\n"),
          filename: 'label.pdf',
          content_type: 'application/pdf'
        )
      end
    end

    trait :with_delivery do
      after(:create) do |shipping_label|
        create(
          :delivery,
          owner: shipping_label.owner,
          store: shipping_label.store,
          shipping_label: shipping_label,
          tracking_number: shipping_label.tracking_number,
          carrier: shipping_label.carrier
        )
        shipping_label.owner.deliveries.reset
      end
    end
  end
end
