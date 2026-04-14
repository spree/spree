module Spree
  module Api
    module V3
      class DeliveryRateSerializer < BaseSerializer
        typelize name: :string, selected: :boolean, delivery_method_id: :string,
                 cost: :string, display_cost: :string,
                 total: :string, display_total: :string,
                 additional_tax_total: :string, display_additional_tax_total: :string,
                 included_tax_total: :string, display_included_tax_total: :string,
                 tax_total: :string, display_tax_total: :string

        attribute :delivery_method_id do |shipping_rate|
          shipping_rate.shipping_method&.prefixed_id
        end

        attributes :name, :selected,
                   :cost, :total,
                   :additional_tax_total, :included_tax_total,
                   :tax_total

        attribute :display_cost do |shipping_rate|
          shipping_rate.display_cost.to_s
        end

        attribute :display_total do |shipping_rate|
          shipping_rate.display_total.to_s
        end

        attribute :display_additional_tax_total do |shipping_rate|
          shipping_rate.display_additional_tax_total.to_s
        end

        attribute :display_included_tax_total do |shipping_rate|
          shipping_rate.display_included_tax_total.to_s
        end

        attribute :display_tax_total do |shipping_rate|
          shipping_rate.display_tax_total.to_s
        end

        one :shipping_method, key: :delivery_method, resource: Spree.api.delivery_method_serializer
      end
    end
  end
end
