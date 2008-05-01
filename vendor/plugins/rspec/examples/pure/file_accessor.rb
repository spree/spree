require File.dirname(__FILE__) + '/spec_helper'
class FileAccessor
  def open_and_handle_with(pathname, processor)
    pathname.open do |io|
      processor.process(io)
    end
  end
end

if __FILE__ == $0
  require File.dirname(__FILE__) + '/io_processor'
  require 'pathname'
  
  accessor = FileAccessor.new
  io_processor = IoProcessor.new
  file = Pathname.new ARGV[0]

  accessor.open_and_handle_with(file, io_processor)
end
