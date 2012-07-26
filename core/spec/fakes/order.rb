require 'fakes/model'

module Spree
  # Every time this file is loaded, this constant needs to be reloaded
  remove_const :FakeOrder if defined?(Spree::FakeOrder)
  class FakeOrder
    include FakeModel
  end
end
