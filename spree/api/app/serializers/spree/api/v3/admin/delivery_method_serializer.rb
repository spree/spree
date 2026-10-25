module Spree
  module Api
    module V3
      module Admin
        class DeliveryMethodSerializer < V3::DeliveryMethodSerializer
          typelize admin_name: [:string, nullable: true],
                   fulfillment_provider: [:string, comment: 'Fulfillment provider. Built-in: manual, digital, pickup, pickup_point. Provider gems register more (e.g. easy_post).'],
                   pickup_point_provider: [:string, nullable: true, comment: 'Pickup point network. None built in; provider gems register them.'],
                   rate_provider: [:string, nullable: true, comment: 'Rate provider; null prices through the calculator. Built-in: internal, freight. Provider gems register more (e.g. easy_post).'],
                   storefront_visible: :boolean, tracking_url: [:string, nullable: true],
                   tax_category_id: [:string, nullable: true],
                   delivery_profile_id: :string,
                   delivery_origin_group_id: [:string, nullable: true],
                   delivery_zone_id: [:string, nullable: true],
                   stock_location_ids: [:string, multi: true],
                   calculator: 'TypedDeliveryCalculator | null',
                   markup_flat: [:string, nullable: true],
                   markup_percent: [:string, nullable: true],
                   available_to_sellers: :boolean,
                   seller_id: [:string, nullable: true],
                   seller_name: [:string, nullable: true]

          attributes :admin_name, :storefront_visible, :tracking_url, :available_to_sellers,
                     created_at: :iso8601, updated_at: :iso8601, deleted_at: :iso8601

          # The flat markup is charged in whatever currency the rate is quoted
          # in, so it is shown as stored rather than rounded to one currency:
          # a rounded figure would be saved back.
          attribute :markup_flat do |record|
            Spree::Money::Rounding.format(record.markup_flat, (current_store || Spree::Current.store)&.default_currency, unit_price: true)
          end

          rate_attributes :markup_percent

          # Which seller runs this method, so the operator's list can say
          # whose it is. Null is the marketplace's own
          # (docs/plans/6.0-multi-vendor-marketplace.md, Decision 13).
          prefixed_id_attributes :seller

          attribute :seller_name do |record|
            record.seller&.name
          end

          many :services, resource: proc { Spree.api.admin_delivery_method_service_serializer }

          # Embedded so a list of methods can be summarized by their
          # eligibility without a request per method.
          many :delivery_method_rules, key: :rules, resource: proc { Spree.api.admin_delivery_method_rule_serializer }

          prefixed_id_attributes :tax_category, :delivery_profile, :delivery_origin_group, :delivery_zone

          attribute :stock_location_ids do |record|
            record.pickup_locations.map(&:prefixed_id)
          end

          api_type_attributes :fulfillment_provider, :pickup_point_provider, :rate_provider

          attribute :calculator do |record|
            calculator = record.calculator
            { type: calculator.class.api_type, preferences: calculator.serialized_preferences } if calculator
          end
        end
      end
    end
  end
end
