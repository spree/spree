module Paperclip

  # Defines the geometry of an image.
  class Geometry
    attr_accessor :height, :width, :modifier

    # Gives a Geometry representing the given height and width
    def initialize width = nil, height = nil, modifier = nil
      @height = height.to_f
      @width  = width.to_f
      @modifier = modifier
    end

    # Uses ImageMagick to determing the dimensions of a file, passed in as either a
    # File or path.
    def self.from_file file
      file = file.path if file.respond_to? "path"
      geometry = begin
                   Paperclip.run("identify", %Q[-format "%wx%h" "#{file}"[0]])
                 rescue PaperclipCommandLineError
                   ""
                 end
      parse(geometry) ||
        raise(NotIdentifiedByImageMagickError.new("#{file} is not recognized by the 'identify' command."))
    end

    # Parses a "WxH" formatted string, where W is the width and H is the height.
    def self.parse string
      if match = (string && string.match(/\b(\d*)x?(\d*)\b([\>\<\#\@\%^!])?/i))
        Geometry.new(*match[1,3])
      end
    end

    # True if the dimensions represent a square
    def square?
      height == width
    end

    # True if the dimensions represent a horizontal rectangle
    def horizontal?
      height < width
    end

    # True if the dimensions represent a vertical rectangle
    def vertical?
      height > width
    end

    # The aspect ratio of the dimensions.
    def aspect
      width / height
    end

    # Returns the larger of the two dimensions
    def larger
      [height, width].max
    end

    # Returns the smaller of the two dimensions
    def smaller
      [height, width].min
    end

    # Returns the width and height in a format suitable to be passed to Geometry.parse
    def to_s
      s = ""
      s << width.to_i.to_s if width > 0
      s << "x#{height.to_i}" if height > 0
      s << modifier.to_s
      s
    end

    # Same as to_s
    def inspect
      to_s
    end

    # Returns the scaling and cropping geometries (in string-based ImageMagick format) 
    # neccessary to transform this Geometry into the Geometry given. If crop is true, 
    # then it is assumed the destination Geometry will be the exact final resolution. 
    # In this case, the source Geometry is scaled so that an image containing the 
    # destination Geometry would be completely filled by the source image, and any 
    # overhanging image would be cropped. Useful for square thumbnail images. The cropping 
    # is weighted at the center of the Geometry.
    def transformation_to dst, crop = false
      if crop
        ratio = Geometry.new( dst.width / self.width, dst.height / self.height )
        scale_geometry, scale = scaling(dst, ratio)
        crop_geometry         = cropping(dst, ratio, scale)
      else
        scale_geometry        = dst.to_s
      end

      [ scale_geometry, crop_geometry ]
    end

    private

    def scaling dst, ratio
      if ratio.horizontal? || ratio.square?
        [ "%dx" % dst.width, ratio.width ]
      else
        [ "x%d" % dst.height, ratio.height ]
      end
    end

    def cropping dst, ratio, scale
      if ratio.horizontal? || ratio.square?
        "%dx%d+%d+%d" % [ dst.width, dst.height, 0, (self.height * scale - dst.height) / 2 ]
      else
        "%dx%d+%d+%d" % [ dst.width, dst.height, (self.width * scale - dst.width) / 2, 0 ]
      end
    end
  end
end
