module SpreePaypalCheckout
  class BaseJob < Spree::BaseJob
    queue_as { SpreePaypalCheckout.queue }
  end
end
