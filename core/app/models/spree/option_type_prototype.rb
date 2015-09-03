module Spree
  class OptionTypePrototype < Spree::Base
    belongs_to :option_type
    belongs_to :prototype
  end
end
