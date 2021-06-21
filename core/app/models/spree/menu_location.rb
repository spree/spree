module Spree
  class MenuLocation < Spree::Base
    belongs_to :menu, touch: true

    before_validation :parameterize_name

    after_save :sync_menu
    after_destroy :sync_menu

    validates :name, uniqueness: true

    private

    def sync_menu
      Menu.refresh_for_locations
    end

    def parameterize_name
      return unless name.present?

      self.parameterized_name = name.parameterize(separator: '_')
    end
  end
end
