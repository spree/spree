module Spree
  class BaseJob < ApplicationJob
    queue_as Spree.queues.default
  end
end
