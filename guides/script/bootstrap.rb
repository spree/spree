#!/usr/bin/env ruby
#/ Usage: script/bootstrap [<options>]
#/ Bootstraps the gem environment.
#/
#/ Options are passed through to the bundle-install command. In most cases you
#/ won't need these. They're used primarily in production environments.
#
# =============================================================================
# Uses bundler to install all gems specified in the Gemfile.
#
# show usage message with --help
if ARGV.include?('--help')
  system "grep '^#/' <'#{__FILE__}' |cut -c4-"
  exit 2
end

# go into the project root because it makes everything easier
root = File.expand_path('../..', __FILE__)
Dir.chdir(root)

# bring in rubygems and make sure bundler is installed.
require 'rubygems'
begin
  require 'bundler'
rescue LoadError => boom
  warn "Bundler not found. Install it with `gem install bundler' and try again."
  exit 1
end

# run bundle-install to install any missing gems
argv  = ['--no-color', 'install']
argv += ARGV
system("bundle", *argv) || begin
  if $?.exitstatus == 127
    warn "bundle executable not found.  Ensure bundler is installed (`gem " +
         "install bundler`) and that the gem bin path is in your PATH"
  end
  exit($?.exitstatus)
end

