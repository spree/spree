require 'spree_core'
require 'spree_auth'
require 'spree_api'
require 'spree_dash'
require 'spree_promo'
require 'spree_sample'

module Spree
  # Used to configure Spree.
  #
  # Example:
  #
  #   Spree::Config do |config|
  #     config.site_name = "An awesome Spree site"
  #   end
  def self.config(&block)
    yield(Spree::Config)
  end
end
