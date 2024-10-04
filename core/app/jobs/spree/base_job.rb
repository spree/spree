module Spree
  class BaseJob < ApplicationJob
    queue_as Spree.default_queue_name
  end
end
