require 'thor'
require 'thor/group'

case ARGV.first
when 'version', '-v', '--version'
  puts Gem.loaded_specs['spree_cli'].version
when 'extension'
  ARGV.shift
  require 'spree_cli/extension'
  SpreeCli::Extension.start
end
