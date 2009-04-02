module Sass::Tree
  class DirectiveNode < Node
    attr_accessor :value

    def initialize(value, options)
      @value = value
      super(options)
    end

    def to_s(tabs)
      if children.empty?
        value + ";"
      else
        result = if @style == :compressed
                   "#{value}{"
                 else
                   "#{'  ' * (tabs - 1)}#{value} {" + (@style == :compact ? ' ' : "\n")
                 end
        was_attr = false
        first = true
        children.each do |child|
          if @style == :compact
            if child.is_a?(AttrNode)
              result << "#{child.to_s(first || was_attr ? 1 : tabs + 1)} "
            else
              if was_attr
                result[-1] = "\n"
              end
              rendered = child.to_s(tabs + 1)
              rendered.lstrip! if first
              result << rendered
            end
            was_attr = child.is_a?(AttrNode)
            first = false
          elsif @style == :compressed
            result << (was_attr ? ";#{child.to_s(1)}" : child.to_s(1))
            was_attr = child.is_a?(AttrNode)
          else
            result << child.to_s(tabs + 1) + "\n"
          end
        end
        result.rstrip + if @style == :compressed
                          "}"
                        else
                          (@style == :expanded ? "\n" : " ") + "}\n"
                        end
      end
    end
  end
end
