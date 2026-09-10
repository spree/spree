module Spree
  module Reporting
    # One evaluated counter: what it is called, what it counts right now, and
    # where that number leads. Never persisted — a fresh evaluation each time
    # the home screen asks.
    class CounterResult
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :key, :string
      attribute :label, :string
      attribute :description, :string
      attribute :value, :integer
      # `{ resource:, filters: [...] }` as registered, or nil.
      attribute :link
    end
  end
end
