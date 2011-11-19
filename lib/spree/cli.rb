require "rubygems"
require "spree/core/version"
require "thor"
require 'spree/extension'
#require 'spree/application'
#require 'spree/test'

module Spree
  class CLI < Thor
    def self.basename
      "spree"
    end

    map "-v"        => "version"
    map "--version" => "version"

    desc "version", "print the current version"
    def version
      shell.say "Spree #{Spree.version}", :green
    end

    desc "extension NAME", "create a new extension with the given name"
    method_option "name", :type => :string
    def extension(name)
      invoke "spree:extension:generate", [options[:name] || name]
    end

    #desc "app NAME", "creates a new rails app configured to use Spree"
    #method_option "name", :type => :string
    #method_option "sample", :type => :boolean, :default => false
    #method_option "bootstrap", :type => :boolean, :default => false
    #method_option "clean", :type => :boolean, :default => false
    #method_option "dir", :type => :string, :default => '.'
    #def app(name)
      #invoke "spree:application:generate", [options[:name] || name, options]
    #end

    #desc "sandbox", "create a sandbox rails app complete with sample data"
    #def sandbox(name="sandbox")
      #invoke "spree:application:generate", [options[:name] || name, {:clean => true, :sample => true,
                                                                     #:bootstrap => true}]
    #end

    #desc "test_app", "create a rails app suitable for Spree testing"
    #method_option "dir", :type => :string, :default => '.'
    #def test_app(name="test_app")
      ##invoke "spree:application:generate", [options[:name] || name, {:clean => true, :dir => options[:dir]}]
      #invoke "spree:test:generate", [options[:dir]]
    #end
  end
end

