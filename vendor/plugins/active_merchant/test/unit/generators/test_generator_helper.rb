require 'test_helper'
require 'fileutils'

# Must set before requiring generator libs.
TMP_ROOT = File.dirname(__FILE__) + "/tmp" unless defined?(TMP_ROOT)
PROJECT_NAME = "myproject" unless defined?(PROJECT_NAME)
app_root = File.join(TMP_ROOT, PROJECT_NAME)
if defined?(APP_ROOT)
  APP_ROOT.replace(app_root)
else
  APP_ROOT = app_root
end

begin
  require 'rubigen'
rescue LoadError
  require 'rubygems'
  require 'rubigen'
end
require 'rubigen/helpers/generator_test_helper'
