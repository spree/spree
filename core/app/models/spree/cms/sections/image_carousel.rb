module Spree::Cms::Sections
  class ImageCarousel < Spree::CmsSection
    LINKED_RESOURCE_TYPE = if Rails::VERSION::STRING < '6.0'
                             ['Spree::Taxon'].freeze
                           else
                             ['Spree::Taxon', 'Spree::Product'].freeze
                           end

    store :content, accessors: [:link_type_one, :link_one, :title_one,
                                :link_type_two, :link_two, :title_two,
                                :link_type_three, :link_three, :title_three], coder: JSON

    store :settings, accessors: [:controls, :indicators, :captions, :crossfade,
                                 :interval, :autoplay, :pause, :wrap], coder: JSON

    attr_accessor :remove_one, :remove_two, :remove_three


    before_save :reset_link_attributes
    after_initialize :default_values
    after_update :remove_images

    def default_values
      self.fit ||= 'Container'
      self.link_type_one ||= ''
      self.link_type_two ||= ''
      self.link_type_three ||= ''

      self.interval ||= 5000
      self.autoplay ||= '1'
      self.controls ||= '0'
      self.indicators ||= '0'
      self.crossfade ||= '0'
      self.captions ||= '0'
      self.pause ||= '1'
      self.wrap ||= '1'
    end

    def data_attributes
      attributes = ["data-interval=#{interval}"]
      attributes.push('data-ride=carousel') if active_setting?(:autoplay)
      attributes.push('data-wrap=false') unless active_setting?(:wrap)
      attributes.push('data-pause=false') unless active_setting?(:pause)
      attributes.join(' ')
    end

    def attached_images
      IMAGE_COUNT.filter_map do |count|
        if try("image_#{count}").attached?
          {
            title: try("title_#{count}"),
            link_type: try("link_type_#{count}"),
            link: try("link_#{count}"),
            file: try("image_#{count}")
          }
        end
      end
    end

    def active_setting?(option)
      option && ActiveRecord::Type::Boolean.new.cast(try(option))
    end

    private

    def reset_link_attributes
      return if Rails::VERSION::STRING < '6.0'

      if link_type_one_changed?
        return if link_type_one_was.nil?

        self.link_one = nil
      end

      if link_type_two_changed?
        return if link_type_two_was.nil?

        self.link_two = nil
      end

      if link_type_three_changed?
        return if link_type_three_was.nil?

        self.link_three = nil
      end
    end

    def remove_images
      image_one.purge if remove_one.present?
      image_two.purge if remove_two.present?
      image_three.purge if remove_three.present?
    end
  end
end
