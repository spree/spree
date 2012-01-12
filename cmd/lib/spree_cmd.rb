require 'thor'
require 'thor/group'

require "spree_cmd/installer"
require "spree_cmd/extension"

module SpreeCmd
  class Command < Thor

    desc "install", "adds spree to an existing rails app"
    method_option :app_path, :type => :string, :desc => 'path to rails application'
    def install(app_path='.')
      invoke Installer
    end

    desc "extension", "builds a spree extension"
    method_option :app_path, :type => :string, :desc => 'path to new extension'
    def extension(app_path)
      invoke Extension
    end

  end
end
