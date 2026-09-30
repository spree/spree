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
  mattr_accessor :revalidations_per_minute, default: 60
end
