module ActsAsTaggableOn
  module TagDecorator
    def self.prepended(base)
      base.include ::Spree::RansackableAttributes
      base.whitelisted_ransackable_attributes = %w[id name]
    end
  end

  Tag.prepend(TagDecorator)
end
