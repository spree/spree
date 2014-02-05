module Spree
  class PaymentCaptureEvent < ActiveRecord::Base
    belongs_to :payment, class_name: 'Spree::Payment'
  end
end
