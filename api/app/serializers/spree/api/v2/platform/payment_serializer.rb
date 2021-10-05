module Spree
  module Api
    module V2
      module Platform
        class PaymentSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :order
          belongs_to :payment_method
          belongs_to :source, polymorphic: true

          has_many :log_entries
          has_many :state_changes
          has_many :payment_capture_events, object_method_name: :capture_events,
                                            id_method_name: :capture_event_ids
          has_many :refunds
        end
      end
    end
  end
end
