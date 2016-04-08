require 'thor'
require 'thor/group'

case ARGV.first
  when 'version', '-v', '--version'
    puts Gem.loaded_specs['spree_cmd'].version
  when 'extension'
    ARGV.shift
    require 'spree_cmd/extension'
    SpreeCmd::Extension.start
  else
    warn "[WARNING] Spree CMD Installer is deprecated. Please follow installation instructions at https://github.com/spree/spree#getting-started"
    ARGV.shift
    require 'spree_cmd/installer'
    SpreeCmd::Installer.start
end
