module Sass::Tree
  class AttrNode < Node
    attr_accessor :name, :value
    
    def initialize(name, value, options)
      @name = name
      @value = value
      super(options)
    end

    def ==(other)
      self.class == other.class && name == other.name && value == other.value && super
    end

    def to_s(tabs, parent_name = nil)
      if value[-1] == ?;
        raise Sass::SyntaxError.new("Invalid attribute: #{declaration.dump} (This isn't CSS!).", @line)
      end
      real_name = name
      real_name = "#{parent_name}-#{real_name}" if parent_name
      
      if value.empty? && children.empty?
        raise Sass::SyntaxError.new("Invalid attribute: #{declaration.dump}.", @line)
      end
      
      join_string = case @style
                    when :compact; ' '
                    when :compressed; ''
                    else "\n"
                    end
      spaces = '  ' * (tabs - 1)
      to_return = ''
      if !value.empty?
        to_return << "#{spaces}#{real_name}:#{@style == :compressed ? '' : ' '}#{value};#{join_string}"
      end
      
      children.each do |kid|
        to_return << kid.to_s(tabs, real_name) << join_string
      end
      
      (@style == :compressed && parent_name) ? to_return : to_return[0...-1]
    end

    protected
    
    def perform!(environment)
      @name = interpolate(@name, environment)
      @value = @value.is_a?(String) ? interpolate(@value, environment) : @value.perform(environment).to_s
      super
    end

    private

    def declaration
      ":#{name} #{value}"
    end

    def invalid_child?(child)
      if !child.is_a?(AttrNode) && !child.is_a?(CommentNode)
        "Illegal nesting: Only attributes may be nested beneath attributes."
      end
    end
  end
end
