module ActsAsTaggableOn
  module TagDecorator
    def self.prepended(base)
      base.include ::Spree::RansackableAttributes
      base.whitelisted_ransackable_attributes = %w[id name]

      base.scope :search_by_name, ->(query) do
        where(arel_table[:name].lower.matches("%#{query.downcase}%"))
      end
    end
  end

  Tag.prepend(TagDecorator)
end
