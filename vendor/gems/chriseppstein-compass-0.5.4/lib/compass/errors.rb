module Compass
  class Error < StandardError
  end

  class FilesystemConflict < Error
  end
end