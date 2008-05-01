$:.push File.join(File.dirname(__FILE__), *%w[.. .. .. lib])
require 'spec'

# Uncommenting next line will break the output story (no output!!)
# rspec_options
options = Spec::Runner::OptionParser.parse(
  ARGV, $stderr, $stdout
)
Spec::Runner::CommandLine.run(options)
