require File.dirname(__FILE__)+'/../test_helper'

class ResponseCollectorTest < Test::Unit::TestCase
  context "yielding a block to a collector object" do
    setup do
      @collector = ResourceController::ResponseCollector.new
      block = lambda do |wants|
        wants.html {}
        wants.js {}
        wants.xml
      end
      block.call(@collector)
    end

    should "collect responses" do
      assert_equal Proc, @collector[:html][1].class, @collector[:html].inspect
      assert_equal Proc, @collector[:js][1].class, @collector[:js].inspect
      assert @collector[:xml][1].nil?, @collector[:xml].inspect
    end
    
    should "clear responses with clear method" do
      @collector.clear
      assert @collector.responses.empty?
    end
    
    should "destroy methods before readding them, if they're already there" do
      @collector.html
      assert @collector[:html][1].nil?
    end
  end
end