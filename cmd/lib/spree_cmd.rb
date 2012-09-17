require 'thor'
require 'thor/group'

case ARGV.first
  when 'version', '-v', '--version'
    puts "outputting version"
    puts Gem.loaded_specs['spree_cmd'].version
  when 'extension'
    ARGV.shift
    require 'spree_cmd/extension'
    SpreeCmd::Extension.start
  else
    ARGV.shift
    require 'spree_cmd/installer'
    SpreeCmd::Installer.start
end
