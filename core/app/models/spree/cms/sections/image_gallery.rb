module Spree::Cms::Sections
  class ImageGallery < Spree::CmsSection
    after_initialize :default_values

    LAYOUT_OPTIONS = ['Default', 'Reversed']
    LABEL_OPTIONS = ['Show', 'Hide']

    store :content, accessors: [:permalink_one, :title_one,
                                :permalink_two, :title_two,
                                :permalink_three, :title_three], coder: JSON

    store :settings, accessors: [:layout_style, :display_labels], coder: JSON

    private

    def default_values
      self.layout_style ||= 'Default'
      self.fit ||= 'Container'
    end
  end
end
