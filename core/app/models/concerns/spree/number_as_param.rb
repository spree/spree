module Spree
  module NumberAsParam
    extend ActiveSupport::Concern

    def to_param
      number.presence.to_s
    end
  end
end
