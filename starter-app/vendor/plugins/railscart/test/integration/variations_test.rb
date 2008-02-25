require "#{File.dirname(__FILE__)}/../test_helper"

class VariationsTest < ActionController::IntegrationTest
  fixtures :categories, :variations, :products
  
  def test_var_save_with_cat
    c1 = categories(:pants)
    c2 = categories(:hats)
    v = variations(:s)
    c1.parent = c2
    c1.save
    c1.reload
    assert_raise(ActiveRecord::RecordNotFound) {Variation.find(v.id)}
  end

  def test_var_save_with_product
    c = categories(:pants)
    p = products(:foo_shirt)
    v = variations(:l)
    p.category = c
    p.save
    assert_raise(ActiveRecord::RecordNotFound) {Variation.find(v.id)}
  end
end