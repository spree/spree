module SpreeStripe
  class BaseJob < Spree::BaseJob
    queue_as { SpreeStripe.queue }
  end
end
