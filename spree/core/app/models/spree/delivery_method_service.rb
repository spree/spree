module Spree
  # One carrier service a delivery method offers ("UPS" / "Ground"), with an
  # optional display label and markup overriding the method's defaults. A
  # method with no service rows offers every service its rate provider
  # returns — rows exist to narrow or customize, never to enable.
  class DeliveryMethodService < Spree.base_class
    has_prefix_id :dms

    acts_as_list scope: :delivery_method

    belongs_to :delivery_method, class_name: 'Spree::DeliveryMethod', inverse_of: :services

    validates :carrier, :service, presence: true
    validates :service, uniqueness: { scope: [:delivery_method_id, :carrier] }
    validates :markup_flat, :markup_percent, numericality: true, allow_nil: true

    # The identity DeliveryRateProvider::Estimate#service_key matches against.
    #
    # @return [String]
    def service_key
      "#{carrier}/#{service}"
    end
  end
end
