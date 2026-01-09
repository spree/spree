module Spree
  # TagList is an Array subclass that provides add/remove methods
  # for compatibility with the acts-as-taggable-on API
  class TagList < Array
    attr_accessor :taggable, :context

    def initialize(*args)
      super(*args.flatten.compact.map(&:to_s).map(&:strip).reject(&:blank?))
    end

    # Add tags to the list
    # @param *tags [String, Array<String>] tags to add
    # @return [TagList] self
    def add(*tags)
      tags.flatten.compact.map(&:to_s).map(&:strip).reject(&:blank?).each do |tag|
        push(tag) unless include?(tag)
      end
      sync_to_taggable if taggable
      self
    end

    # Remove tags from the list
    # @param *tags [String, Array<String>] tags to remove
    # @return [TagList] self
    def remove(*tags)
      tags.flatten.compact.map(&:to_s).map(&:strip).each do |tag|
        delete(tag)
      end
      sync_to_taggable if taggable
      self
    end

    # Convert to a comma-separated string
    def to_s
      join(', ')
    end

    private

    def sync_to_taggable
      return unless taggable && context

      taggable.set_tag_list_on(context, self.dup)
    end
  end
end
