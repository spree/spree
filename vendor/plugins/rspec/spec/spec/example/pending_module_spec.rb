module Spec
  module Example
    describe Pending do
      
      it 'should raise an ExamplePendingError if no block is supplied' do
        lambda {
          include Pending
          pending "TODO"
        }.should raise_error(ExamplePendingError, /TODO/)
      end
      
      it 'should raise an ExamplePendingError if a supplied block fails as expected' do
        lambda {
          include Pending
          pending "TODO" do
            raise "oops"
          end
        }.should raise_error(ExamplePendingError, /TODO/)
      end
      
      it 'should raise an ExamplePendingError if a supplied block fails as expected with a mock' do
        lambda {
          include Pending
          pending "TODO" do
            m = mock('thing')
            m.should_receive(:foo)
            m.rspec_verify
          end
        }.should raise_error(ExamplePendingError, /TODO/)
      end
      
      it 'should raise a PendingExampleFixedError if a supplied block starts working' do
        lambda {
          include Pending
          pending "TODO" do
            # success!
          end
        }.should raise_error(PendingExampleFixedError, /TODO/)
      end
    end
  end
end
