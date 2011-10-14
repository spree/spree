After('@custom_permissions') do
  # This will only run before steps within scenarios tagged
  # with @custom_permissions
  Spree::Ability.abilities.clear
end

