# encoding: utf-8

require 'money'

module Spree
  class Money
    attr_reader :money

    delegate :cents, :to => :money

    def initialize(amount, options={})
      @money = self.class.parse([amount, (options[:currency] || Spree::Config[:currency])].join)
      @options = {}
      @options[:with_currency] = Spree::Config[:display_currency]
      @options[:symbol_position] = Spree::Config[:currency_symbol_position].to_sym
      @options[:no_cents] = Spree::Config[:hide_cents]
      @options[:decimal_mark] = Spree::Config[:currency_decimal_mark]
      @options[:thousands_separator] = Spree::Config[:currency_thousands_separator]
      @options[:sign_before_symbol] = Spree::Config[:currency_sign_before_symbol]
      @options.merge!(options)
      # Must be a symbol because the Money gem doesn't do the conversion
      @options[:symbol_position] = @options[:symbol_position].to_sym
    end

    # This method is being deprecated in Money 6.1.0, so now lives here.
    def self.parse(input, currency = nil)
      i = input.to_s.strip

      # raise Money::Currency.table.collect{|c| c[1][:symbol]}.inspect

      # Check the first character for a currency symbol, alternatively get it
      # from the stated currency string
      c = if ::Money.assume_from_symbol && i =~ /^(\$|€|£)/
        case i
        when /^\$/ then "USD"
        when /^€/ then "EUR"
        when /^£/ then "GBP"
        end
      else
        i[/[A-Z]{2,3}/]
      end

      # check that currency passed and embedded currency are the same,
      # and negotiate the final currency
      if currency.nil? and c.nil?
        currency = ::Money.default_currency
      elsif currency.nil?
        currency = c
      elsif c.nil?
        currency = currency
      elsif currency != c
        # TODO: ParseError
        raise ArgumentError, "Mismatching Currencies"
      end
      currency = ::Money::Currency.wrap(currency)

      fractional = extract_cents(i, currency)
      ::Money.new(fractional, currency)
    end

    # This method is being deprecated in Money 6.1.0, so now lives here.
    def self.extract_cents(input, currency = Money.default_currency)
      # remove anything that's not a number, potential thousands_separator, or minus sign
      num = input.gsub(/[^\d.,'-]/, '')

      # set a boolean flag for if the number is negative or not
      negative = num =~ /^-|-$/ ? true : false

      # decimal mark character
      decimal_char = currency.decimal_mark

      # if negative, remove the minus sign from the number
      # if it's not negative, the hyphen makes the value invalid
      if negative
        num = num.sub(/^-|-$/, '')
      end

      raise ArgumentError, "Invalid currency amount (hyphen)" if num.include?('-')

      #if the number ends with punctuation, just throw it out.  If it means decimal,
      #it won't hurt anything.  If it means a literal period or comma, this will
      #save it from being mis-interpreted as a decimal.
      num.chop! if num.match(/[\.|,]$/)

      # gather all decimal_marks within the result number
      used_delimiters = num.scan(/[^\d]/)

      # determine the number of unique decimal_marks within the number
      #
      # e.g.
      # $1,234,567.89 would return 2 (, and .)
      # $125,00 would return 1
      # $199 would return 0
      # $1 234,567.89 would raise an error (decimal_marks are space, comma, and period)
      case used_delimiters.uniq.length
        # no decimal_mark or thousands_separator; major (dollars) is the number, and minor (cents) is 0
      when 0 then major, minor = num, 0

        # two decimal_marks, so we know the last item in this array is the
        # major/minor thousands_separator and the rest are decimal_marks
      when 2
        thousands_separator, decimal_mark = used_delimiters.uniq

        # remove all thousands_separator, split on the decimal_mark
        major, minor = num.gsub(thousands_separator, '').split(decimal_mark)
        min = 0 unless min
      when 1
        # we can't determine if the comma or period is supposed to be a decimal_mark or a thousands_separator
        # e.g.
        # 1,00 - comma is a thousands_separator
        # 1.000 - period is a thousands_separator
        # 1,000 - comma is a decimal_mark
        # 1,000,000 - comma is a decimal_mark
        # 10000,00 - comma is a thousands_separator
        # 1000,000 - comma is a thousands_separator

        # assign first decimal_mark for reusability
        decimal_mark = used_delimiters.first

        # When we have identified the decimal mark character
        if decimal_char == decimal_mark
          major, minor = num.split(decimal_char)

        else
          # decimal_mark is used as a decimal_mark when there are multiple instances, always
          if num.scan(decimal_mark).length > 1 # multiple matches; treat as decimal_mark
            major, minor = num.gsub(decimal_mark, ''), 0
          else
            # ex: 1,000 - 1.0000 - 10001.000
            # split number into possible major (dollars) and minor (cents) values
            possible_major, possible_minor = num.split(decimal_mark)
            possible_major ||= "0"
            possible_minor ||= "00"

            # if the minor (cents) length isn't 3, assign major/minor from the possibles
            # e.g.
            #   1,00 => 1.00
            #   1.0000 => 1.00
            #   1.2 => 1.20
            if possible_minor.length != 3 # thousands_separator
              major, minor = possible_major, possible_minor
            else
              # minor length is three
              # let's try to figure out intent of the thousands_separator

              # the major length is greater than three, which means
              # the comma or period is used as a thousands_separator
              # e.g.
              #   1000,000
              #   100000,000
              if possible_major.length > 3
                major, minor = possible_major, possible_minor
              else
                # number is in format ###{sep}### or ##{sep}### or #{sep}###
                # handle as , is sep, . is thousands_separator
                if decimal_mark == '.'
                  major, minor = possible_major, possible_minor
                else
                  major, minor = "#{possible_major}#{possible_minor}", 0
                end
              end
            end
          end
        end
      else
        # TODO: ParseError
        raise ArgumentError, "Invalid currency amount"
      end

      # build the string based on major/minor since decimal_mark/thousands_separator have been removed
      # avoiding floating point arithmetic here to ensure accuracy
      cents = (major.to_i * currency.subunit_to_unit)
      # Because of an bug in JRuby, we can't just call #floor
      minor = minor.to_s
      minor = if minor.size < currency.decimal_places
                (minor + ("0" * currency.decimal_places))[0,currency.decimal_places].to_i
              elsif minor.size > currency.decimal_places
                if minor[currency.decimal_places,1].to_i >= 5
                  minor[0,currency.decimal_places].to_i+1
                else
                  minor[0,currency.decimal_places].to_i
                end
              else
                minor.to_i
              end

      cents += minor

      # if negative, multiply by -1; otherwise, return positive cents
      negative ? cents * -1 : cents
    end

    def to_s
      @money.format(@options)
    end

    def to_html(options = { :html => true })
      output = @money.format(@options.merge(options))
      if options[:html]
        # 1) prevent blank, breaking spaces
        # 2) prevent escaping of HTML character entities
        output = output.gsub(" ", "&nbsp;").html_safe
      end
      output
    end

    def as_json(*)
      to_s
    end

    def ==(obj)
      @money == obj.money
    end
  end
end
