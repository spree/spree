module Spree
  class MenuLocation < Spree::Base
    before_validation :parameterize_name

    after_save :sync_menu
    after_commit :sync_menu
    around_destroy :remove_location_from_menu

    validates :name, :parameterized_name, presence: true
    validates :name, :parameterized_name, uniqueness: true

    private

    def sync_menu
      Menu.refresh_for_locations
    end

    def remove_location_from_menu
      # Capture the deleted location parameterized_name
      location_method_name = "for_#{parameterized_name}".to_sym

      # Delete the menu_location from the DB
      yield

      # Remove the dynamically created class method if it exists in Spree::Menu
      if Spree::Menu.respond_to?(location_method_name)
        Menu.singleton_class.send :undef_method, location_method_name
      end

      # If a rollback occurs, it won't matter, as we re-sync the menu_locations and dynamically
      # add the class methods that exists in the database.
      sync_menu
    end

    def parameterize_name
      return unless name.present?

      self.parameterized_name = name.parameterize(separator: '_')
    end
  end
end
