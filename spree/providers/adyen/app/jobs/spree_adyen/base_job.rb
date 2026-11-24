module SpreeAdyen
  class BaseJob < Spree::BaseJob
    queue_as { SpreeAdyen.queue }
  end
end
