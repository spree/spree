module Spree
  module Api
    module V3
      # Payload of the shipping_label.* events. Labels have no storefront
      # serializer — a customer never sees one — so the event shape is
      # declared here rather than found by convention.
      class ShippingLabelEventSerializer < Admin::ShippingLabelSerializer
      end
    end
  end
end
