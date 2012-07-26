require 'fakes/model'

module Spree
  # Every time this file is loaded, this constant needs to be reloaded
  remove_const :FakeOrder if defined?(FakeOrder)
  class FakeOrder
    include FakeModel
  end
end
