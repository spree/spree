require 'strscan'

# :stopdoc:
module Haml
  # This module contains functionality that's shared across Haml and Sass.
  module Shared
    def self.handle_interpolation(str)
      scan = StringScanner.new(str)
      yield scan while scan.scan(/(.*?)(\\*)\#\{/)
      scan.rest
    end

    def self.balance(scanner, start, finish, count = 0)
      str = ''
      scanner = StringScanner.new(scanner) unless scanner.is_a? StringScanner
      regexp = Regexp.new("(.*?)[\\#{start.chr}\\#{finish.chr}]", Regexp::MULTILINE)
      while scanner.scan(regexp)
        str << scanner.matched
        count += 1 if scanner.matched[-1] == start
        count -= 1 if scanner.matched[-1] == finish
        return [str.strip, scanner.rest] if count == 0
      end
    end

    def self.human_indentation(indentation, was = false)
      if !indentation.include?(?\t)
        noun = 'space'
      elsif !indentation.include?(?\s)
        noun = 'tab'
      else
        return indentation.inspect + (was ? ' was' : '')
      end

      singular = indentation.length == 1
      if was
        was = singular ? ' was' : ' were'
      else
        was = ''
      end

      "#{indentation.length} #{noun}#{'s' unless singular}#{was}"
    end
  end
end
# :startdoc:
