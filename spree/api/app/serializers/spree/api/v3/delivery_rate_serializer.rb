module Spree
  module Api
    module V3
      class DeliveryRateSerializer < BaseSerializer
        typelize name: :string, selected: :boolean, delivery_method_id: :string,
                 cost: :string, display_cost: :string,
                 total: :string, display_total: :string,
                 additional_tax_total: :string, display_additional_tax_total: :string,
                 included_tax_total: :string, display_included_tax_total: :string,
                 tax_total: :string, display_tax_total: :string,
                 carrier: [:string, nullable: true],
                 service_level: [:string, nullable: true],
                 estimated_delivery_date: [:string, nullable: true]

        attribute :delivery_method_id do |deliver_rate|
          deliver_rate.delivery_method&.prefixed_id
        end

        # Carrier, service level and delivery date come from the rate provider
        # and are what the customer chooses between; nil on calculator-priced
        # methods. Provider metadata stays admin-only.
        attributes :name, :selected,
                   :cost, :total,
                   :additional_tax_total, :included_tax_total,
                   :tax_total,
                   :carrier, :service_level, :estimated_delivery_date

        attribute :display_cost do |deliver_rate|
          deliver_rate.display_cost.to_s
        end

        attribute :display_total do |deliver_rate|
          deliver_rate.display_total.to_s
        end

        attribute :display_additional_tax_total do |deliver_rate|
          deliver_rate.display_additional_tax_total.to_s
        end

        attribute :display_included_tax_total do |deliver_rate|
          deliver_rate.display_included_tax_total.to_s
        end

        attribute :display_tax_total do |deliver_rate|
          deliver_rate.display_tax_total.to_s
        end

        one :delivery_method, resource: proc { Spree.api.delivery_method_serializer }
      end
    end
  end
end
