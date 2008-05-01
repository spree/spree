$:.unshift File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'lib')
$:.unshift File.join(File.dirname(__FILE__), '..')

require 'spec'
require 'behaviour/examples/examples'
require 'behaviour/stories/stories'
