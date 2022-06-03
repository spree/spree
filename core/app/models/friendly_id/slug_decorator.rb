module FriendlyId
  module SlugDecorator
    def self.prepended(base)
      include Discard::Model
      base.discard_column = :deleted_at
      default_scope -> { kept }
    end
  end
end

FriendlyId::Slug.prepend FriendlyId::SlugDecorator
