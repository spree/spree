require 'test_helper'

class ProductScopeTest < ActiveSupport::TestCase
  context "ProductScope" do
    setup do
      @numbers = %w{one two three four five six}
      @taxonomy = Taxonomy.find_or_create_by_name("test_taxonomy")
      @taxons = (0..1).map{|x|
        Taxon.find_by_name("test_taxon_#{x}") ||
          Taxon.create(:name => "test_taxon_#{x}", :taxonomy_id => @taxonomy.id)
      }
      @products = (0..4).map do |x|
        unless pr = Product.find_by_name("test product #{@numbers[x]}")
          pr = Factory(:product,
            :price => (x+1)*10,
            :name => "test product #{@numbers[x]}"
          )
          pr.taxons << @taxons[x%2]
          pr.save
        end
        pr
      end
    end

    should "allow for creating named scope from searchlogic" do
      @ps = ProductScope.new({
          # I'm almost sure noone will use it, so t'll be automatically generated,
          # on first hit, and that's what we're testing
          :name => "product_option_types_option_type_created_at_null",
          :arguments => []
        })
      assert @ps.valid?
    end

    should "allow for creating named scope from Scopes::Product" do
      @ps = ProductScope.new({
          :name => "price_between",
          :arguments => [1,2]
        })
      assert @ps.valid?
    end

    should "find products" do
      @ps = ProductScope.new({
          # I'm almost sure noone will use it, so t'll be automatically generated,
          # on first hit, and that's what we're testing
          :name => "price_between",
          :arguments => [10, 30]
        })
      assert @ps.valid?
      products = Product.find(:all, :joins => :master, :conditions => ["variants.price between ? AND ?", 10, 30])
      assert_equal(products.map(&:name), @ps.products.map(&:name))
    end


    teardown do
      Taxonomy.delete_all "name like 'test_%'"
      Taxon.delete_all "name like 'test_%'"
      @products && @products.each(&:destroy)
    end
  end
end
