class DataTooShort < StandardError; end

class IoProcessor
  # Does some fancy stuff unless the length of +io+ is shorter than 32
  def process(io)
    raise DataTooShort if io.read.length < 32
  end
end
