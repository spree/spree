require 'spree_core'
require 'spree_auth'
require 'spree_api'
require 'spree_dash'
require 'spree_promo'
require 'spree_sample'

module Spree
  def self.config(&block)
    yield(Spree::Config)
  end
end
