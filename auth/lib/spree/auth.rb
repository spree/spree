require 'spree_core'
require 'devise'
require 'cancan'

require 'spree/token_resource'

module Spree
  module Auth
		def self.config(&block)
	    yield(Spree::Auth::Config)
	  end
  end
end

require 'spree/auth/engine'
