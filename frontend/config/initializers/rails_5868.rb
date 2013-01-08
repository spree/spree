# Temporary fix for
# NoMethodError: undefined method `gsub' for #<Arel::Nodes::Ascending:...>
# See https://github.com/rails/rails/issues/5868
class Arel::Nodes::Ordering
  def gsub(*a, &b)
    to_sql.gsub(*a, &b)
  end
end
