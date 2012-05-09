Spree.user_class.class_eval do
  has_and_belongs_to_many :roles, :join_table => 'spree_roles_users'

  def generate_api_key!
    self.api_key = SecureRandom.hex(24)
    save!
  end

  def clear_api_key!
    self.api_key = nil
    save!
  end

  # has_spree_role? simply needs to return true or false whether a user has a role or not.
  def has_spree_role?(role_in_question)
    roles.any? { |role| role.name == role_in_question.to_s }
  end
end
