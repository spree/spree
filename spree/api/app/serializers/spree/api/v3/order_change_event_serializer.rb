module Spree
  module Api
    module V3
      class OrderChangeEventSerializer < BaseSerializer
        typelize status: :string,
                 order_id: :string,
                 return_id: [:string, nullable: true],
                 exchange_id: [:string, nullable: true],
                 claim_id: [:string, nullable: true],
                 requested_at: [:string, nullable: true],
                 confirmed_at: [:string, nullable: true],
                 canceled_at: [:string, nullable: true]

        attributes :status,
                   requested_at: :iso8601, confirmed_at: :iso8601, canceled_at: :iso8601,
                   created_at: :iso8601, updated_at: :iso8601

        prefixed_id_attributes :order, :return, :exchange, :claim

        money_attributes :previous_total, :new_total, :balance_delta,
                         currency: ->(order_change) { order_change.order.currency },
                         descriptions: {
                           previous_total: 'The order total before the change was confirmed. Null until it is.',
                           new_total: 'The order total after the change was confirmed. Null until it is.',
                           balance_delta: 'How far confirming moved the order total: positive when the customer owes more. ' \
                                          'Null until the change is confirmed.'
                         }
      end
    end
  end
end
