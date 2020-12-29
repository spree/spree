module FriendlyId
  module SlugDecorator
    def self.prepended(base)
      base.acts_as_paranoid
    end
  end
end

FriendlyId::Slug.prepend FriendlyId::SlugDecorator
