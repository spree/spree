require 'thor'
require 'thor/group'

module SpreeCmd
  class Command

    if ARGV.first == 'version'
      puts Gem.loaded_specs['spree_cmd'].version
    elsif ARGV.first == 'extension'
      ARGV.shift
      require 'spree_cmd/extension'
      SpreeCmd::Extension.start
    else
      ARGV.shift
      require 'spree_cmd/installer'
      SpreeCmd::Installer.start
    end
  end
end