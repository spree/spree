# Used just for us to develop rspec with Autotest
# We could symbolic link rspec/vendor/plugins/rspec => rspec/., but 
# this leads to a problem with subversion on windows.  Autotest
# uses Ruby's load path, which contains ".", so this is a workaround
# (albeit, an unclean one)
require File.dirname(__FILE__) + "/../lib/autotest/discover.rb"
