require 'tracking_number'

# This is a very basic service that can be used to track packages.
# It uses the tracking_number gem to validate and build tracking urls.
# https://github.com/jkeen/tracking_number
# You can create your own service by subclassing this one and using 3rd party services, eg. AfterShip or Shippo
module Spree
  module TrackingNumbers
    class BaseService
      def initialize(tracking_number)
        @tracking = TrackingNumber.new(tracking_number)
      end

      attr_reader :tracking

      delegate :valid?, :tracking_url, to: :tracking
    end
  end
end
