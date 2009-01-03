require File.dirname(__FILE__) + '/../../spec_helper.rb'

class LiarLiarPantsOnFire
  def respond_to?(sym, incl_private=false)
    true
  end
  
  def self.respond_to?(sym, incl_private=false)
    true
  end
end
  
describe 'should_receive' do
  before(:each) do
    @liar = LiarLiarPantsOnFire.new
  end
  
  it "should work when object lies about responding to a method" do
    @liar.should_receive(:something)
    @liar.something
  end

  it 'should work when class lies about responding to a method' do
    LiarLiarPantsOnFire.should_receive(:something)
    LiarLiarPantsOnFire.something
  end
  
  it 'should cleanup after itself' do
    (class << LiarLiarPantsOnFire; self; end).instance_methods.should_not include("something")
  end
end

