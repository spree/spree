module Spree
  module Core
    module ControllerHelpers
      module StrongParameters
        def permitted_attributes
          Spree::PermittedAttributes
        end

        delegate *Spree::PermittedAttributes::ATTRIBUTES,
                 to: :permitted_attributes,
                 prefix: :permitted

        def permitted_payment_attributes
          permitted_attributes.payment_attributes + [
            source_attributes: permitted_source_attributes
          ]
        end

        def permitted_checkout_attributes
          permitted_attributes.checkout_attributes + [
            bill_address_attributes: permitted_address_attributes,
            ship_address_attributes: permitted_address_attributes,
            payments_attributes: permitted_payment_attributes,
            shipments_attributes: permitted_shipment_attributes
          ]
        end

        def permitted_order_attributes
          permitted_checkout_attributes + [
            line_items_attributes: permitted_line_item_attributes
          ]
        end

        def permitted_product_attributes
          permitted_attributes.product_attributes + [
            product_properties_attributes: permitted_product_properties_attributes
          ]
        end
      end
    end
  end
end
