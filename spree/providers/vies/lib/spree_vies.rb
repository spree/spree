require 'valvat'
require 'spree_core'
require 'spree_vies/engine'

module SpreeVies
  # How long a registry answer is trusted before `spree_vies:revalidate` asks
  # again. Businesses get deregistered, so a number verified once does not stay
  # verified.
  mattr_accessor :freshness, default: 90.days

  # How many re-validation checks `spree_vies:revalidate` releases per minute.
  # Keeps a large backlog, such as every number on the day the gem is
  # installed, from reaching VIES all at once.
  class << self
    attr_reader :revalidations_per_minute

    def revalidations_per_minute=(rate)
      unless rate.is_a?(Integer) && rate.positive?
        raise ArgumentError, "SpreeVies.revalidations_per_minute must be a positive whole number, got #{rate.inspect}"
      end

      @revalidations_per_minute = rate
    end
  end
  self.revalidations_per_minute = 60
end
