module Spree
  module Api
    module V2
      module Platform
        class PaymentSerializer < BaseSerializer
          include ResourceSerializerConcern

          belongs_to :order, serializer: Spree::Api::Dependencies.platform_order_serializer.constantize
          belongs_to :payment_method, serializer: Spree::Api::Dependencies.platform_payment_method_serializer.constantize
          belongs_to :source, polymorphic: true, serializer: Spree::Api::Dependencies.platform_payment_source_serializer.constantize

          has_many :log_entries, serializer: Spree::Api::Dependencies.platform_log_entry_serializer.constantize
          has_many :state_changes, serializer: Spree::Api::Dependencies.platform_state_change_serializer.constantize
          has_many :payment_capture_events, object_method_name: :capture_events,
                                            id_method_name: :capture_event_ids,
                                            serializer: Spree::Api::Dependencies.platform_payment_capture_event_serializer.constantize
          has_many :refunds, serializer: Spree::Api::Dependencies.platform_refund_serializer.constantize
        end
      end
    end
  end
end
