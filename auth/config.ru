# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../spec/dummy/config/environment',  __FILE__)
run Dummy::Application
