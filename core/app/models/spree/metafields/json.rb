module Spree
  module Metafields
    class Json < Spree::Metafield
      normalizes :value, with: lambda { |value|
        # If value is a string that looks like a hash (e.g., "{:foo=>\"bar\"}"), try to convert it to JSON
        stripped = value.to_s.strip
        return nil if stripped.blank?

        begin
          # Try to parse as JSON first
          JSON.parse(stripped)
        rescue JSON::ParserError
          # Try to convert Ruby hash string to JSON string, then parse
          if stripped.match?(/\A\{.*\}\z/)
            # Replace Ruby hash rocket and symbol syntax with JSON syntax
            json_like = stripped
              .gsub(/:(\w+)\s*=>/, '"\1":') # :foo=>"bar" => "foo":"bar"
              .gsub(/=>/, ':')              # fallback for any remaining =>
              .gsub(/([a-zA-Z0-9_]+):/, '"\1":') # foo: "bar" => "foo": "bar"
              .gsub("nil", "null")
              .gsub("'", '"')
            JSON.parse(json_like)
          else
            raise
          end
        end
      }
    end
  end
end
