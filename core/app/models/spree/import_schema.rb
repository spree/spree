module Spree
  class ImportSchema
    FIELDS = []

    def fields
      self.class::FIELDS
    end

    def required_fields
      self.class::FIELDS.select { |f| f[:required] }.map { |f| f[:name] }
    end

    def optional_fields
      self.class::FIELDS.reject { |f| f[:required] }.map { |f| f[:name] }
    end

    def headers
      self.class::FIELDS.map { |f| f[:name] }
    end
  end
end
