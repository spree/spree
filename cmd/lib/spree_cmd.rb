require 'thor'
require 'thor/group'

require 'spree_cmd/installer'
require 'spree_cmd/extension'
require 'spree_cmd/version'

module SpreeCmd
  class Command < Thor

    desc 'install', 'adds spree to an existing rails app'
    method_option :app_path, :type => :string, :desc => 'path to rails application'
    def install(app_path = '.')
      invoke Installer
    end

    desc 'extension', 'builds a spree extension'
    method_option :app_path, :type => :string, :desc => 'path to new extension'
    def extension(app_path)
      invoke Extension
    end

		desc 'version', 'display spree_cmd version'
    def version
      invoke Version
    end

  end
end
