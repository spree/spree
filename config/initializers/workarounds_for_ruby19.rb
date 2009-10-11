if RUBY_VERSION.to_f >= 1.9

  ActiveSupport::MessageVerifier.class_eval do
      private
        # constant-time comparison algorithm to prevent timing attacks
        def secure_compare(a, b)
          return false unless a.bytesize == b.bytesize

          l = a.unpack "C#{a.bytesize}"

          res = 0
          b.each_byte { |byte| res |= byte ^ l.shift }
          res == 0
        end
  end


  class String
    def mb_chars
      self.force_encoding(Encoding::UTF_8)
    end
    
    alias_method(:orig_concat, :concat)
    def concat(value)
      orig_concat value.force_encoding(Encoding::UTF_8)
    end
  end

end
