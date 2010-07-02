require 'test_helper'

class ProductGroupTest < ActiveSupport::TestCase
  context "ProductGroup" do
    setup do
      @numbers = %w{one two three four five six}
      @taxonomy = Taxonomy.create!(:name => "test_taxonomy")
      @taxons = (0..1).map{|x|
        Taxon.create!(:name => "test_taxon_#{x}", :taxonomy_id => @taxonomy.id)
      }
      @products = (0..4).map do |x|
        pr = Factory(:product,
                     :price => (x+1)*10,
                     :name => "test product #{@numbers[x]}")
        pr.taxons << @taxons[x%2]
        pr.save!
        pr
      end
    end

    context "scope merging" do
      setup do
        @pg = ProductGroup.new :name => "foo"
        @pg.save!
      end

      should "use last order passed" do
        @pg.order_scope = "descend_by_name"
        @pg.order_scope = "ascend_by_updated_at"
        assert_equal("ascend_by_updated_at", @pg.order_scope)
      end
    end

    ###################### NORMAL URL ########################################
    context "from normal url" do
      setup do
        @pg = ProductGroup.from_url('/s/name_like_any/one,two,five/master_price_lt/30/descend_by_name')
      end

      should "not be saved and have sane defaults" do
        assert(@pg.kind_of?(ProductGroup),
          "ProductGroup is a #{@pg.class.name} instead of Project Group")
        assert(@pg.new_record?,
          "ProductGroup is not new record")
        assert(@pg.name.blank?,
          "ProductGroup.name is not blank but #{@pg.name}")
        assert(@pg.permalink.blank?,
          "ProductGroup.permalink is not blank but #{@pg.permalink}")
      end

      should "generate correct scopes" do
        assert @pg.product_scopes

        assert_equal_list_hash([
            {
              "product_group_id"=>nil,
              "name"=>"descend_by_name",
              "arguments"=>[]
            },{
              "product_group_id"=>nil,
              "name"=>"name_like_any",
              "arguments"=>["one", "two", "five"]
            },{
              "product_group_id"=>nil,
              "name"=>"master_price_lt",
              "arguments"=>["30"]
            }
          ], @pg.product_scopes.map(&:attributes))
      end

      should "find products" do
        @pg.update_attribute(:name, 'foo')
        products = %w{one two five}.map{|name|
          Product.find(:all, :conditions => ["name LIKE ?", "%#{name}%"])
        }.flatten.reject{|pr| pr.master.price >= 30}.sort_by{|pr| pr.name}.reverse
        assert_equal(products.map(&:name), @pg.dynamic_products.map(&:name))

      end

      should "have correct order" do
        @pg.update_attribute(:name, 'foo')
        assert_equal("descend_by_name",    @pg.order_scope)
        assert_equal("products.name DESC", @pg.dynamic_products.scope(:find)[:order])
      end
    end

    ###################### NORMAL URL WITH TAXON################################
    context "from normal url with taxon" do
      setup do
        @pg = ProductGroup.from_url('/t/test_taxon_0/s/name_like_any/one,two,five/master_price_lt/30')
      end

      should "not be saved and have sane defaults" do
        assert(@pg.kind_of?(ProductGroup),
          "ProductGroup is a #{@pg.class.name} instead of Project Group")
        assert(@pg.new_record?,
          "ProductGroup is not new record")
        assert(@pg.name.blank?,
          "ProductGroup.name is not blank but #{@pg.name}")
        assert(@pg.permalink.blank?,
          "ProductGroup.permalink is not blank but #{@pg.permalink}")
      end

      should "generate correct scopes" do
        assert @pg.product_scopes

        assert_equal_list_hash([
            {
              "product_group_id"=>nil,
              "name"=>"name_like_any",
              "arguments"=>["one", "two", "five"]
            },{
              "product_group_id"=>nil,
              "name"=>"master_price_lt",
              "arguments"=>["30"]
            },{
              "product_group_id"=>nil,
              "name"=>"in_taxon",
              "arguments" => ["test_taxon_0"]
            }
          ], @pg.product_scopes.map(&:attributes))
      end

      should "find products" do
        @pg.update_attribute(:name, 'foo')
        products = %w{one five}.map{|name|
          Product.find(:all, :conditions => ["name LIKE ?", "%#{name}%"])
        }.flatten.reject{|pr| pr.master.price >= 30}
        assert_equal(products.map(&:name), @pg.dynamic_products.map(&:name))

      end

      should "have correct order" do
        @pg.update_attribute(:name, 'foo')
        assert_equal(nil, @pg.order_scope)
        assert_equal(nil, @pg.dynamic_products.scope(:find)[:order])
      end
    end

    ###################### copy of another product group #########################
    context "from another product group" do
      setup do
        ProductGroup.create!({
            :name => "test pg",
            :order_scope => "descend_by_updated_at",
            :product_scopes_attributes => [
              {
                "name"=>"name_like_any",
                "arguments"=>["three", "four", "five"]
              }
            ]
          })
        @pg = ProductGroup.from_url('/pg/test-pg')
      end

      should "not be saved and have sane defaults" do
        assert(@pg.kind_of?(ProductGroup),
          "ProductGroup is a #{@pg.class.name} instead of Project Group")
        assert(@pg.new_record?,
          "ProductGroup is not new record")
        assert(@pg.name.blank?,
          "ProductGroup.name is not blank but #{@pg.name}")
        assert(@pg.permalink.blank?,
          "ProductGroup.permalink is not blank but #{@pg.permalink}")
      end

      should "generate correct scopes" do
        assert @pg.product_scopes

        assert_equal_list_hash([
            {
              "product_group_id"=>nil,
              "name"=>"descend_by_updated_at",
              "arguments"=>[]
            },{
              "product_group_id"=>nil,
              "name"=>"name_like_any",
              "arguments"=>["three", "four", "five"]
            }
          ], @pg.product_scopes.map(&:attributes))
      end

      should "find products" do
        @pg.update_attribute(:name, 'foo')
        products = %w{three four five}.map{|name|
          Product.find(:all, :conditions => ["name LIKE ?", "%#{name}%"])
        }.flatten.sort_by{|pr| pr.name}
        assert_equal(products.map(&:name), @pg.dynamic_products.map(&:name).sort)
      end

      should "have correct order" do
        @pg.update_attribute(:name, 'foo')
        assert_equal("descend_by_updated_at",    @pg.order_scope)
        assert_equal("products.updated_at DESC", @pg.dynamic_products.scope(:find)[:order])
      end
    end

    ###################### copy of another product group with taxon #############
    context "from another product group with taxon" do
      setup do
        ProductGroup.create!({
            :name => "test pg",
            :order_scope => "descend_by_updated_at",
            :product_scopes_attributes => [
              {
                "name"=>"name_like_any",
                "arguments"=>["three", "four", "five"]
              }
            ]
          })
        @pg = ProductGroup.from_url('/t/test_taxon_1/pg/test-pg')
      end

      should "not be saved and have sane defaults" do
        assert(@pg.kind_of?(ProductGroup),
          "ProductGroup is a #{@pg.class.name} instead of Project Group")
        assert(@pg.new_record?,
          "ProductGroup is not new record")
        assert(@pg.name.blank?,
          "ProductGroup.name is not blank but #{@pg.name}")
        assert(@pg.permalink.blank?,
          "ProductGroup.permalink is not blank but #{@pg.permalink}")
      end

      should "generate correct scopes" do
        assert @pg.product_scopes

        assert_equal_list_hash([
            {
              "product_group_id"=>nil,
              "name"=>"descend_by_updated_at",
              "arguments"=>[]
            },{
              "product_group_id"=>nil,
              "name"=>"name_like_any",
              "arguments"=>["three", "four", "five"]
            },{
              "product_group_id"=>nil,
              "name"=>"in_taxon",
              "arguments" => ["test_taxon_1"]
            }
          ], @pg.product_scopes.map(&:attributes))
      end

      should "find products" do
        @pg.update_attribute(:name, 'foo')
        products = %w{four}.map{|name|
          Product.find(:all, :conditions => ["name LIKE ?", "%#{name}%"])
        }.flatten.sort_by{|pr| pr.updated_at}.reverse
        assert_equal(products.map(&:name), @pg.dynamic_products.map(&:name))
      end

      should "have correct order" do
        @pg.update_attribute(:name, 'foo')
        assert_equal("descend_by_updated_at",    @pg.order_scope)
        assert_equal("products.updated_at DESC", @pg.dynamic_products.scope(:find)[:order])
      end
    end  

    context "new_from_products" do
      setup do
        @products = Product.limit(2)
        @pg = ProductGroup.new_from_products(@products, :name => 'With 2 products')
      end
      should "contain the correct products" do
        assert_equal 2, @pg.products.length
        assert_equal @products.map(&:id).sort, @pg.products.map(&:id).sort
      end
    end

  end
end
