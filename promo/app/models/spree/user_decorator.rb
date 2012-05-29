if Spree.user_class
  Spree.user_class.class_eval do
    has_and_belongs_to_many :roles, :class_name => "Spree::Role", :foreign_key => :user_id
  end
end
