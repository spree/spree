module Spree::StoreCredits::Configuration
  class << self
    require 'ostruct'

    delegate :non_expiring_credit_types, :credit_to_new_allocation, to: :configs

    def set_configs(options = {})
      @configs = OpenStruct.new(options)
    end

    private

    def configs
      @configs
    end
  end
end
