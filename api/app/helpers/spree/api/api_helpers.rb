module Spree
  module Api
    module ApiHelpers
      def required_fields_for(model)
        required_fields = model._validators.select do |field, validations|
          validations.any? { |v| v.is_a?(ActiveModel::Validations::PresenceValidator) }
        end.map(&:first) # get fields that are invalid
        # Permalinks presence is validated, but are really automatically generated
        # Therefore we shouldn't tell API clients that they MUST send one through
        required_fields.map!(&:to_s).delete("permalink")
        required_fields
      end

      def product_attributes
        [:id, :name, :description, :price,
         :available_on, :permalink, :count_on_hand, :meta_description, :meta_keywords]
      end

      def variant_attributes
        [:id, :name, :count_on_hand, :sku, :price, :weight, :height, :width, :depth, :is_master, :cost_price]
      end

      def image_attributes
        [:id, :position, :attachment_content_type, :attachment_file_name, :type, :attachment_updated_at, :attachment_width, :attachment_height, :alt]
      end

      def option_value_attributes
        [:id, :name, :presentation, :option_type_name, :option_type_id]
      end

      def order_attributes
        [:id, :number, :item_total, :total, :state, :adjustment_total, :credit_total, :user_id, :created_at, :updated_at, :completed_at, :payment_total, :shipment_state, :payment_state, :email, :special_instructions]
      end

      def line_item_attributes
        [:id, :quantity, :price, :variant_id]
      end

      def option_type_attributes
        [:id, :name, :presentation, :position]
      end

      def payment_attributes
        [:id, :source_type, :source_id, :amount, :payment_method_id, :response_code, :state, :avs_response, :created_at, :updated_at]
      end

      def payment_method_attributes
        [:id, :name, :description]
      end
    end
  end
end
