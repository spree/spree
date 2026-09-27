require 'valvat'
require 'spree_core'
require 'spree_vies/engine'

module SpreeVies
  # How long a registry answer is trusted before `spree_vies:revalidate` asks
  # again. Businesses get deregistered, so a number verified once does not stay
  # verified.
  mattr_accessor :freshness, default: 90.days
end
