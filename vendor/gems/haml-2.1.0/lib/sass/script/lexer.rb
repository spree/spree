require 'strscan'

module Sass
  module Script
    class Lexer # :nodoc:
      Token = Struct.new(:type, :value, :line, :offset)

      OPERATORS = {
        '+' => :plus,
        '-' => :minus,
        '*' => :times,
        '/' => :div,
        '%' => :mod,
        '(' => :lparen,
        ')' => :rparen,
        ',' => :comma,
        'and' => :and,
        'or' => :or,
        'not' => :not,
        '==' => :eq,
        '!=' => :neq,
        '>=' => :gte,
        '<=' => :lte,
        '>' => :gt,
        '<' => :lt,
        '#{' => :begin_interpolation,
        '}' => :end_interpolation,
      }

      # We'll want to match longer names first
      # so that > and < don't clobber >= and <=
      OP_NAMES = OPERATORS.keys.sort_by {|o| -o.size}

      REGULAR_EXPRESSIONS = {
        :whitespace => /\s*/,
        :variable => /!(\w+)/,
        :ident => /(\\.|\#\{|[^\s\\+\-*\/%(),=!])+/,
        :string_end => /((?:\\.|\#[^{]|[^"\\#])*)(?:"|(?=#\{))/,
        :number => /(-)?(?:(\d*\.\d+)|(\d+))([a-zA-Z%]+)?/,
        :color => /\##{"([0-9a-fA-F]{1,2})" * 3}|(#{Color::HTML4_COLORS.keys.join("|")})/,
        :bool => /(true|false)\b/,
        :op => %r{(#{Regexp.union(*OP_NAMES.map{|s| Regexp.new(Regexp.escape(s) + (s =~ /\w$/ ? '(?:\b|$)' : ''))})})}
      }

      def initialize(str, line, offset)
        @scanner = str.is_a?(StringScanner) ? str : StringScanner.new(str)
        @line = line
        @offset = offset
        @prev = nil
      end

      def next
        @tok ||= read_token
        @tok, tok = nil, @tok
        @prev = tok
        return tok
      end

      def peek
        @tok ||= read_token
      end

      def done?
        whitespace unless after_interpolation?
        @scanner.eos? && @tok.nil?
      end

      def rest
        @scanner.rest
      end

      private

      def read_token
        return if done?

        value = token
        unless value
          raise SyntaxError.new("Syntax error in '#{@scanner.string}' at character #{current_position}.")
        end
        Token.new(value.first, value.last, @line, last_match_position)
      end

      def whitespace
        @scanner.scan(REGULAR_EXPRESSIONS[:whitespace])
      end

      def token
        return string('') if after_interpolation?
        variable || string || number || color || bool || op || ident
      end

      def variable
        return unless @scanner.scan(REGULAR_EXPRESSIONS[:variable])
        [:const, @scanner[1]]
      end

      def ident
        return unless s = @scanner.scan(REGULAR_EXPRESSIONS[:ident])
        [:ident, s.gsub(/\\(.)/, '\1')]
      end

      def string(start_char = '"')
        return unless @scanner.scan(/#{start_char}#{REGULAR_EXPRESSIONS[:string_end]}/)
        [:string, Script::String.new(@scanner[1].gsub(/\\([^0-9a-f])/, '\1').gsub(/\\([0-9a-f]{1,4})/, "\\\\\\1"))]
      end

      def begin_interpolation
        @scanner.scan
      end

      def number
        return unless @scanner.scan(REGULAR_EXPRESSIONS[:number])
        value = @scanner[2] ? @scanner[2].to_f : @scanner[3].to_i
        value = -value if @scanner[1]
        [:number, Script::Number.new(value, Array(@scanner[4]))]
      end

      def color
        return unless @scanner.scan(REGULAR_EXPRESSIONS[:color])
        value = if @scanner[4]
                  color = Color::HTML4_COLORS[@scanner[4].downcase]
                else
                  (1..3).map {|i| @scanner[i]}.map {|num| num.ljust(2, num).to_i(16)}
                end
        [:color, Script::Color.new(value)]
      end

      def bool
        return unless s = @scanner.scan(REGULAR_EXPRESSIONS[:bool])
        [:bool, Script::Bool.new(s == 'true')]
      end

      def op
        return unless op = @scanner.scan(REGULAR_EXPRESSIONS[:op])
        [OPERATORS[op]]
      end

      def current_position
        @offset + @scanner.pos + 1
      end

      def last_match_position
        current_position - @scanner.matchedsize
      end

      def after_interpolation?
        @prev && @prev.type == :end_interpolation
      end
    end
  end
end
