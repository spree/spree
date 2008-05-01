require File.dirname(__FILE__) + '/spec_helper'
require File.dirname(__FILE__) + '/file_accessor'
require 'stringio'

describe "A FileAccessor" do
  # This sequence diagram illustrates what this spec specifies.
  #
  #                  +--------------+     +----------+     +-------------+
  #                  | FileAccessor |     | Pathname |     | IoProcessor |
  #                  +--------------+     +----------+     +-------------+
  #                         |                  |                  |
  #   open_and_handle_with  |                  |                  |
  #   -------------------->| |           open  |                  |
  #                        | |--------------->| |                 |
  #                        | | io             | |                 |
  #                        | |<...............| |                 |
  #                        | |                 |     process(io)  |
  #                        | |---------------------------------->| |
  #                        | |                 |                 | |
  #                        | |<..................................| |
  #                         |                  |                  |
  #
  it "should open a file and pass it to the processor's process method" do
    # This is the primary actor
    accessor = FileAccessor.new

    # These are the primary actor's neighbours, which we mock.
    file = mock "Pathname"
    io_processor = mock "IoProcessor"
    
    io = StringIO.new "whatever"
    file.should_receive(:open).and_yield io
    io_processor.should_receive(:process).with(io)
    
    accessor.open_and_handle_with(file, io_processor)
  end

end
