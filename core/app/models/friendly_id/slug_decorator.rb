module FriendlyId
  module SlugDecorator
    def self.prepended(base)
      base
    end
  end
end

FriendlyId::Slug.prepend FriendlyId::SlugDecorator
