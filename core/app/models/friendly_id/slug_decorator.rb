module FriendlyId
  module SlugDecorator
    def self.prepended(base)
      base.discard_column = :deleted_at
    end
  end
end

FriendlyId::Slug.prepend FriendlyId::SlugDecorator
