require 'resolv'
require 'mail'

class EmailValidator < ActiveModel::EachValidator
  LOCAL_PART_SPECIAL_CHARS = /[\!\#\$\%\&\'\*\-\/\=\?\+\-\^\_\`\{\|\}\~]/
  # supports all possible domains https://iwantmyname.com/domains/domain-name-registration-list-of-extensions
  # reference from https://en.wikipedia.org/wiki/Email_address
  def validate_each(record, attribute, value)
    begin
      m = Mail::Address.new(value)
      r = m.domain && m.address == value
      r &&= validate_local(m.local)
      r &&= validate_domain(m.domain)
      r &&= validate_mx(m.domain) if options[:check_mx]
    rescue StandardError
      r = false
    end
    record.errors.add(attribute, :invalid, { value: value }.merge!(options)) unless r
  end

  # validate local part of email address
  def validate_local(local)
    in_quoted_pair = false
    in_quoted_string = false
    (0..local.length - 1).each do |i|
      ord = local[i].ord

      # backslash signifies the start of a quoted pair
      if ord == 92 && i < local.length - 1
        # must be in quoted string per http://www.rfc-editor.org/errata_search.php?rfc=3696
        return false if !in_quoted_string
        in_quoted_pair = true
        next
      end

      # double quote delimits quoted strings
      if ord == 34 || (ord == 92 && local[i].delete('\\').ord == 34)
        return false if !in_quoted_string && i.positive? && local[i - 1].present? && local[i - 1].ord != 46
        return false if in_quoted_string && i < local.length - 1 && local[i + 1].present? && local[i + 1].ord != 46
        in_quoted_string = !in_quoted_string
        next
      end

      # accept anything if it's got a backslash before it
      if in_quoted_pair
        in_quoted_pair = false
        next
      end

      # accept anything if it's inside delimits quoted
      next if in_quoted_string

      next if local[i, 1] =~ /[a-z0-9]/i
      next if local[i, 1] =~ LOCAL_PART_SPECIAL_CHARS

      # period must be followed by something
      if ord == 46
        return false if i.zero? || i == local.length - 1 # can't be first or last char
        next unless local[i + 1].ord == 46 # can't be followed by a period
      end
      return false
    end

    return false if in_quoted_string # unbalanced quotes
    true
  end

  # validate domain part of email address
  def validate_domain(domain)
    parts = domain.downcase.split('.', -1)
    # ipv4
    return true if parts.length == 4 && parts.first[0] == '[' && parts.last[-1] == ']' && parts.all? do |part|
      part = part[1..-1] if part == parts.first # removed '[' if it is first part
      part = part[0..-2] if part == parts.last # removed ']' if it is last part
      part =~ /\A[0-9]+\Z/ && part.to_i.between?(0, 255)
    end

    # Empty parts (double period) or invalid chars
    return false if parts.any? do |part|
      part.nil? ||
      part.empty? ||
      part.length > 63 || # each label being limited to a length of 63 characters
      !(part =~ /\A[[:alnum:]\-]+\Z/) ||
      part[0, 1] == '-' || part[-1, 1] == '-' # hyphen should not at beginning or end of part
    end
    # TLD is too short or does not contain a char or hyphen
    return false if parts[-1].length < 2 || !(parts[-1] =~ /[a-z\-]/)
    true
  end

  # resolve dns for domain
  def validate_mx(domain)
    Resolv::DNS.open do |dns|
      @mx = dns.getresources(domain, Resolv::DNS::Resource::IN::MX) +
            dns.getresources(domain, Resolv::DNS::Resource::IN::A)
    end
    @mx.size.positive?
  end
end
