ANALYTICS_ID=ENV['ANALYTICS_ID']
EDGE = ENV['EDGE']

pwd = File.dirname(__FILE__)
$: << pwd
$: << File.join(pwd, "activesupport/lib")
$: << File.join(pwd, "actionpack/lib")

require "action_controller"
require "action_view"

require 'action_controller'
require 'action_view'
require 'redcloth'
require 'fileutils'

module Spree
  autoload :Generator, "spree/generator"
  autoload :Indexer, "spree/indexer"
  autoload :Helpers, "spree/helpers"
  autoload :TextileExtensions, "spree/textile_extensions"
end

RedCloth.send(:include, Spree::TextileExtensions)

if $0 == __FILE__
  Spree::Generator.new(ENV['OUTPUT_DIR']).generate
end
