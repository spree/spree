module Spree
  module Reporting
    # One evaluated counter: which counter it is, what it counts right now,
    # and where that number leads. Never persisted — a fresh evaluation each
    # time the home screen asks. No copy: the key identifies the counter and
    # the client translates it.
    class CounterResult
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :key, :string
      attribute :value, :integer
      # `{ resource:, filters: [...] }` as registered, or nil.
      attribute :link
      # Sidebar entry key this count badges, or nil.
      attribute :nav, :string
    end
  end
end
