module Spree
  module NumberAsParam
    extend ActiveSupport::Concern

    included do
      extend FriendlyId

      friendly_id :number
    end
  end
end
