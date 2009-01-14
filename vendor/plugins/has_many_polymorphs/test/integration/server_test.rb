
require "#{File.dirname(__FILE__)}/../test_helper"
require 'open-uri'

# Start the server

class ServerTest < Test::Unit::TestCase

  PORT = 43040
  URL = "http://localhost:#{PORT}/"

  def setup
    @pid = Process.fork do
       Dir.chdir RAILS_ROOT do
         # print "S"
         exec("script/server -p #{PORT} &> #{LOG}")
       end
     end
     sleep(5)
  end
  
  def teardown
    # Process.kill(9, @pid) doesn't work because Mongrel has double-forked itself away
    `ps awx | grep #{PORT} | grep -v grep | awk '{print $1}'`.split("\n").each do |pid|
      system("kill -9 #{pid}")
      # print "K"
    end
    sleep(2)
    @pid = nil
  end
  
  def test_association_reloading
    assert_match(/Bones: index/, open(URL + 'bones').read)
    assert_match(/Bones: index/, open(URL + 'bones').read)
    assert_match(/Bones: index/, open(URL + 'bones').read)
    assert_match(/Bones: index/, open(URL + 'bones').read)
  end
  
  def test_verify_autoload_gets_invoked_in_console
    # XXX Probably can use script/runner to test this
  end
  
end