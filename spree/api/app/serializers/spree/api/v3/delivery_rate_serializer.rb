module Spree
  module Api
    module V3
      class DeliveryRateSerializer < BaseSerializer
        typelize name: :string, selected: :boolean, delivery_method_id: :string,
                 carrier: [:string, nullable: true],
                 service_level: [:string, nullable: true],
                 estimated_delivery_date: [:string, nullable: true],
                 unpriced: :boolean,
                 freight_summary: [:FreightSummary, nullable: true]

        prefixed_id_attributes :delivery_method

        # Carrier, service level and delivery date come from the rate provider
        # and are what the customer chooses between; nil on calculator-priced
        # methods. Provider metadata stays admin-only.
        attributes :name, :selected

        money_attributes :cost, :total, :additional_tax_total, :included_tax_total, :tax_total

        attributes :carrier, :service_level, :estimated_delivery_date,
                   :unpriced

        # What the shipment looks like to a freight forwarder — cartons,
        # pallets, cubic meters, gross weight. Present only on freight rates;
        # it is what a buyer sees in place of a price they cannot be quoted
        # yet, and stays readable on the placed order because the provider
        # froze it here when it quoted.
        one :freight_summary, resource: proc { Spree.api.freight_summary_serializer }

        money_attributes :display_cost, :display_total, :display_additional_tax_total,
                         :display_included_tax_total, :display_tax_total

        one :delivery_method, resource: proc { Spree.api.delivery_method_serializer }
      end
    end
  end
end
