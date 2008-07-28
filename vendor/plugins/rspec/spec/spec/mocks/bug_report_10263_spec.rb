describe "Mock" do
  before do
    @mock = mock("test mock")
  end
  
  specify "when one example has an expectation (non-mock) inside the block passed to the mock" do
    @mock.should_receive(:msg) do |b|
      b.should be_true #this call exposes the problem
    end
    @mock.msg(false) rescue nil
  end
  
  specify "then the next example should behave as expected instead of saying" do
    @mock.should_receive(:foobar)
    @mock.foobar
    @mock.rspec_verify
    begin
      @mock.foobar
    rescue Exception => e
      e.message.should == "Mock 'test mock' received unexpected message :foobar with (no args)"
    end
  end 
end

