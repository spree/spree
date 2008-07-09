# Spree Extension Manager.
# 
# Installing extensions:
#
#   $ ./script/extension install public-git-repo-address-for-extension

$verbose = false

require 'open-uri'
require 'fileutils'
require 'tempfile'

include FileUtils

class SpreeEnvironment
  attr_reader :root

  def initialize(dir)
    @root = dir
  end

  def self.find(dir=nil)
    dir ||= pwd
    while dir.length > 1
      return new(dir) if File.exist?(File.join(dir, 'config', 'environment.rb'))
      dir = File.dirname(dir)
    end
  end

  def self.default
    @default ||= find
  end
  
  def self.default=(spree_env)
    @default = spree_env
  end 
end

class Extension
  attr_reader :name, :uri
  
  def initialize(uri, name=nil)
    @uri = uri
    guess_name(uri)
  end
  
  def to_s
    "#{@name.ljust(30)}#{@uri}"
  end
  
  def svn_url?
    @uri =~ /svn(?:\+ssh)?:\/\/*/
  end
  
  def git_url?
    @uri =~ /^git:\/\// || @uri =~ /\.git$/
  end
  
  def installed?
    File.directory?("#{spree_env.root}/vendor/extensions/#{name}")
  end
  
  def install(options = {})
    method = :clone
    uninstall if installed? and options[:force]

    unless installed?
      send("install_using_#{method}", options)
    else
      puts "already installed: #{name} (#{uri}).  pass --force to reinstall"
    end
  end

  def uninstall
    path = "#{spree_env.root}/vendor/extensions/#{name}"
    if File.directory?(path)
      puts "Removing 'vendor/extensions/#{name}'" if $verbose
      rm_r path
    else
      puts "Extension doesn't exist: #{path}"
    end
  end
  
  private
  
    def install_using_clone(options = {})
      git_command :clone, options
    end
    
    def git_command(cmd, options = {})
      root = spree_env.root
      mkdir_p "#{root}/vendor/extensions"
      base_cmd = "git #{cmd} --depth 1 #{uri} \"#{root}/vendor/extensions/#{name}\""
      puts base_cmd if $verbose
      puts "removing: #{root}/vendor/extensions/#{name}/.git"
      system(base_cmd)
      rm_rf "#{root}/vendor/extensions/#{name}/.git"
    end

    def guess_name(url)
      @name = File.basename(url)
      if @name == 'trunk' || @name.empty?
        @name = File.basename(File.dirname(url))
      end
      @name.gsub!(/\.git$/, '') if @name =~ /\.git$/
      @name.gsub!(/^spree-/, '') #if @name =~ /^spree-/
      @name.gsub!(/^spree_/, '') #if @name =~ /^spree_/
      @name.gsub!(/-/, '_')
    end
    
    def spree_env
      @spree_env || SpreeEnvironment.default
    end
end

# load default environment and parse arguments
require 'optparse'
module Commands

  class Extension
    attr_reader :environment, :script_name#, :sources
    def initialize
      @environment = SpreeEnvironment.default
      @spree_root = SpreeEnvironment.default.root
      @script_name = File.basename($0) 
      @sources = []
    end
    
    def environment=(value)
      @environment = value
      SpreeEnvironment.default = value
    end
    
    def options
      OptionParser.new do |o|
        o.set_summary_indent('  ')
        o.banner =    "Usage: #{@script_name} [OPTIONS] command"
        o.define_head "Spree extension manager."
        
        o.separator ""        
        o.separator "GENERAL OPTIONS"
        
        o.on("-r", "--root=DIR", String,
             "Set an explicit Spree vendor/extensions directory.",
             "Default: #{@spree_root}") { |@spree_root| self.environment = SpreeEnvironment.new(@spree_root) }
        o.on("-v", "--verbose", "Turn on verbose output.") { |$verbose| }
        o.on("-h", "--help", "Show this help message.") { puts o; exit }
        
        o.separator ""
        o.separator "COMMANDS"
        
        o.separator "  install    Install extension(s) from known URLs."
        o.separator "  remove     Uninstall extensions."        
        o.separator ""
        o.separator "EXAMPLES"
        o.separator "  Install an extension from a git URL:"
        o.separator "    #{@script_name} install git://github.com/SomeGuy/my_awesome_extension.git\n"
      end
    end
    
    def parse!(args=ARGV)
      general, sub = split_args(args)
      options.parse!(general)
      
      command = general.shift
      if command =~ /^(install|remove|update)$/
        command = Commands.const_get(command.capitalize).new(self)
        command.parse!(sub)
      else
        puts "Unknown command: #{command}"
        puts options
        exit 1
      end
    end
    
    def split_args(args)
      left = []
      left << args.shift while args[0] and args[0] =~ /^-/
      left << args.shift if args[0]
      return [left, args]
    end
    
    def self.parse!(args=ARGV)
      Extension.new.parse!(args)
    end
  end  
  
  class Install
    def initialize(base_command)
      @base_command = base_command
      @method = :http
      @options = { :quiet => false, :force => false }
    end
    
    def options
      OptionParser.new do |o|
        o.set_summary_indent('  ')
        o.banner =    "Usage: #{@base_command.script_name} install EXTENSION [EXTENSION [EXTENSION] ...]"
        o.define_head "Install one or more extensions."
        o.separator   ""
        o.separator   "Options:"
        o.on(         "-q", "--quiet",
                      "Suppresses the output from installation.",
                      "Ignored if -v is passed (./script/extension -v install ...)") { |v| @options[:quiet] = true }
        o.on(         "-f", "--force",
                      "Reinstalls an extension if it's already installed.") { |v| @options[:force] = true }
        o.separator   ""
        o.separator   "You must specify extensions as absolute URLs to a plugin repository."
      end
    end

    def parse!(args)
      options.parse!(args)
      environment = @base_command.environment
      install_method = :clone
      puts "Extensions will be installed using #{install_method}" if $verbose
      args.each do |name|
        ::Extension.new(name).install(@options)
      end
    rescue StandardError => e
      puts "Extension not found: #{args.inspect}"
      puts e.inspect if $verbose
      exit 1
    end
  end
  
  class Remove
    def initialize(base_command)
      @base_command = base_command
    end
    
    def options
      OptionParser.new do |o|
        o.set_summary_indent('  ')
        o.banner =    "Usage: #{@base_command.script_name} remove name [name]..."
        o.define_head "Remove extensions."
      end
    end
    
    def parse!(args)
      options.parse!(args)
      root = @base_command.environment.root
      args.each do |name|
        ::Extension.new(name).uninstall
      end
    end
  end
end

Commands::Extension.parse!