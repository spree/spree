require 'test/unit'
# Load the environment
unless defined? SPREE_ROOT
  ENV["RAILS_ENV"] = "test"
  case
  when ENV["SPREE_ENV_FILE"]
    require File.dirname(ENV["SPREE_ENV_FILE"]) + "/boot"
  when File.dirname(__FILE__) =~ %r{vendor/spree/vendor/extensions}
    require "#{File.expand_path(File.dirname(__FILE__) + "/../../../../../../")}/config/boot"
  else
    require "#{File.expand_path(File.dirname(__FILE__) + "/../../../../")}/config/boot"
  end
end
require "#{SPREE_ROOT}/test/test_helper"

require 'factories/promotion_factory.rb'

class MockOrder
  def initialize(attrs = {})
    @attrs = attrs
    attrs.each do |k,v|
      send("#{k}=", v)
    end
  end
  attr_accessor :item_total, :user, :line_items
end
