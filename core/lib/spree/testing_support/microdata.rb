module Spree
  module TestingSupport
    module Microdata
      # code extracted and modified from 'microdata' gem
      class Document
        attr_reader :items, :doc

        def initialize(content)
          @doc = Nokogiri::HTML(content)
          @items = extract_items
        end

        def extract_items
          itemscopes = @doc.search('//*[@itemscope and not(@itemprop)]')
          return nil unless itemscopes

          itemscopes.map do |itemscope|
            Item.new(itemscope)
          end
        end
      end

      class Item
        attr_reader :type, :properties, :id

        def initialize(top_node)
          @top_node = top_node
          @type = extract_item_type
          @id   = extract_item_id
          @properties = {}
          add_item_ref_properties(@top_node)
          parse_elements(extract_elements(@top_node))
        end

        def to_hash
          hash = {}
          hash[:id] = id if id
          hash[:type] = type if type
          hash[:properties] = {}
          properties.each do |name, values|
            final_values = values.map do |value|
              if value.reponds_to?(:to_hash)
                value.to_hash
              else
                value
              end
            end
            hash[:properties][name] = final_values
          end
          hash
        end

        private

        def extract_elements(node)
          node.search('./*')
        end

        def extract_item_id
          (value = @top_node.attribute('itemid')) ? value.value : nil
        end

        def extract_item_type
          (value = @top_node.attribute('itemtype')) ? value.value.split(' ') : nil
        end

        def parse_elements(elements)
          elements.each { |element| parse_element(element) }
        end

        def parse_element(element)
          item_scope = element.attribute('itemscope')
          item_prop = element.attribute('itemprop')
          internal_elements = extract_elements(element)
          add_item_prop(element) if item_scope || item_prop
          parse_elements(internal_elements) if internal_elements && !item_scope
        end

        # Add an 'itemprop' to the properties
        def add_item_prop(item_prop)
          properties = Itemprop.parse(item_prop, @page_url)
          properties.each { |name, value| (@properties[name] ||= []) << value }
        end

        # Add any properties referred to by 'itemref'
        def add_item_ref_properties(element)
          item_ref = element.attribute('itemref')
          if item_ref
            item_ref.value.split(' ').each { |id| parse_elements(find_with_id(id)) }
          end
        end

        # Find an element with a matching id
        def find_with_id(id)
          @top_node.search("//*[@id='#{id}']")
        end
      end

      class Itemprop
        NON_TEXTCONTENT_ELEMENTS = {
          'a' => 'href',        'area' => 'href',
          'audio' => 'src',     'embed' => 'src',
          'iframe' => 'src',    'img' => 'src',
          'link' => 'href',     'meta' => 'content',
          'object' => 'data',   'source' => 'src',
          'time' => 'datetime', 'track' => 'src',
          'video' => 'src'
        }.freeze
        URL_ATTRIBUTES = ['data', 'href', 'src'].freeze

        # A Hash representing the properties.
        # Hash is of the form {'property name' => 'value'}
        attr_reader :properties

        # Create a new Itemprop object
        # [element]  The itemprop element to be parsed
        # [page_url] The url of the page, including filename, used to form
        #            absolute urls
        def initialize(element, page_url = nil)
          @element = element
          @page_url = page_url
          @properties = extract_properties
        end

        # Parse the element and return a hash representing the properties.
        # Hash is of the form {'property name' => 'value'}
        # [element]  The itemprop element to be parsed
        # [page_url] The url of the page, including filename, used to form
        #            absolute urls
        def self.parse(element, page_url = nil)
          new(element, page_url).properties
        end

        private

        def extract_properties
          prop_names = extract_property_names
          prop_names.each_with_object({}) do |name, memo|
            memo[name] = extract_property
          end
        end

        # This returns an empty string if can't form a valid
        # absolute url as per the Microdata spec.

        def make_absolute_url(url)
          return url unless URI.parse(url).relative?
          begin
            URI.parse(@page_url).merge(url).to_s
          rescue URI::Error
            url
          end
        end

        def non_textcontent_element?(element)
          NON_TEXTCONTENT_ELEMENTS.has_key?(element)
        end

        def url_attribute?(attribute)
          URL_ATTRIBUTES.include?(attribute)
        end

        def extract_property_names
          itemprop_attr = @element.attribute('itemprop')
          itemprop_attr ? itemprop_attr.value.split : []
        end

        def extract_property_value
          element = @element.name
          if non_textcontent_element?(element)
            attribute = NON_TEXTCONTENT_ELEMENTS[element]
            value = @element.attribute(attribute).value
            url_attribute?(attribute) ? make_absolute_url(value) : value
          else
            @element.inner_text.strip
          end
        end

        def extract_property
          if @element.attribute('itemscope')
            Item.new(@element)
          else
            extract_property_value
          end
        end
      end
    end
  end
end
