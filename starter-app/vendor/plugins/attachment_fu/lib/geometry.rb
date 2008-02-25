# This Geometry class was yanked from RMagick.  However, it lets ImageMagick handle the actual change_geometry.
# Use #new_dimensions_for to get new dimensons
# Used so I can use spiffy RMagick geometry strings with ImageScience
class Geometry
  # ! and @ are removed until support for them is added
  FLAGS = ['', '%', '<', '>']#, '!', '@']
  RFLAGS = { '%' => :percent,
             '!' => :aspect,
             '<' => :>,
             '>' => :<,
             '@' => :area }

  attr_accessor :width, :height, :x, :y, :flag

  def initialize(width=nil, height=nil, x=nil, y=nil, flag=nil)
    # Support floating-point width and height arguments so Geometry
    # objects can be used to specify Image#density= arguments.
    raise ArgumentError, "width must be >= 0: #{width}"   if width < 0
    raise ArgumentError, "height must be >= 0: #{height}" if height < 0
    @width  = width.to_f
    @height = height.to_f
    @x      = x.to_i
    @y      = y.to_i
    @flag   = flag
  end

  # Construct an object from a geometry string
  RE = /\A(\d*)(?:x(\d+))?([-+]\d+)?([-+]\d+)?([%!<>@]?)\Z/

  def self.from_s(str)
    raise(ArgumentError, "no geometry string specified") unless str
  
    if m = RE.match(str)
      new(m[1].to_i, m[2].to_i, m[3].to_i, m[4].to_i, RFLAGS[m[5]])
    else
      raise ArgumentError, "invalid geometry format"
    end
  end

  # Convert object to a geometry string
  def to_s
    str = ''
    str << "%g" % @width if @width > 0
    str << 'x' if (@width > 0 || @height > 0)
    str << "%g" % @height if @height > 0
    str << "%+d%+d" % [@x, @y] if (@x != 0 || @y != 0)
    str << FLAGS[@flag.to_i]
  end
  
  # attempts to get new dimensions for the current geometry string given these old dimensions.
  # This doesn't implement the aspect flag (!) or the area flag (@).  PDI
  def new_dimensions_for(orig_width, orig_height)
    new_width  = orig_width
    new_height = orig_height

    case @flag
      when :percent
        scale_x = @width.zero?  ? 100 : @width
        scale_y = @height.zero? ? @width : @height
        new_width    = scale_x.to_f * (orig_width.to_f  / 100.0)
        new_height   = scale_y.to_f * (orig_height.to_f / 100.0)
      when :<, :>, nil
        scale_factor =
          if new_width.zero? || new_height.zero?
            1.0
          else
            if @width.nonzero? && @height.nonzero?
              [@width.to_f / new_width.to_f, @height.to_f / new_height.to_f].min
            else
              @width.nonzero? ? (@width.to_f / new_width.to_f) : (@height.to_f / new_height.to_f)
            end
          end
        new_width  = scale_factor * new_width.to_f
        new_height = scale_factor * new_height.to_f
        new_width  = orig_width  if @flag && orig_width.send(@flag,  new_width)
        new_height = orig_height if @flag && orig_height.send(@flag, new_height)
    end

    [new_width, new_height].collect! { |v| v.round }
  end
end

class Array
  # allows you to get new dimensions for the current array of dimensions with a given geometry string
  #
  #   [50, 64] / '40>' # => [40, 51]
  def /(geometry)
    raise ArgumentError, "Only works with a [width, height] pair" if size != 2
    raise ArgumentError, "Must pass a valid geometry string or object" unless geometry.is_a?(String) || geometry.is_a?(Geometry)
    geometry = Geometry.from_s(geometry) if geometry.is_a?(String)
    geometry.new_dimensions_for first, last
  end
end