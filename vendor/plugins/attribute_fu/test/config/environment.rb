$:.reject! { |e| e.include? 'TextMate' }
RAILS_GEM_VERSION = '2.0.2' unless defined? RAILS_GEM_VERSION

require File.join(File.dirname(__FILE__), 'boot')

Rails::Initializer.run do |config|
  config.action_controller.session = {
    :session_key => '_test_session',
    :secret      => '012cbaf0c3d36504f3b1bc397b838d24'
  }

  config.load_paths += %W( #{RAILS_ROOT}/../lib )
end

require "#{RAILS_ROOT}/../init"
