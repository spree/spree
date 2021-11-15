require 'spree/core'

require 'rabl'
require 'responders'

module Spree
  module Api
  end
end

require 'spree/api/api_dependencies'
require 'spree/api/engine'

Dir["#{File.dirname(__FILE__)}/factories/**"].each do |f|
  load File.expand_path(f)
end
