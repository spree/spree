export function productsWorkbook(storeProductPropertiesCount) {
  const fields = [
    {
      key: "product_id",
      label: "Product Identifier",
      type: "number",
      constraints: [
        { type: "required" }
      ]
    },
    {
      key: "slug",
      label: "Slug",
      type: "string"
    },
    {
      key: "sku",
      label: "SKU",
      type: "string",
      constraints: [
        { type: "unique" }
      ]
    },
    {
      key: "name",
      label: "Name",
      type: "string"
    },
    {
      key: "description",
      label: "Description",
      type: "string"
    },
    {
      key: "price",
      label: "Price",
      type: "number",
      constraints: [
        { type: "required" }
      ]
    },
    {
      key: "compare_at_price",
      label: "Compare at price",
      type: "number"
    },
    {
      key: "status",
      label: "Status",
      type: "enum",
      config: {
        options: [
          { value: "draft", label: "Draft" },
          { value: "active", label: "Active" },
          { value: "archived", label: "Archived" }
        ]
      }
    },
    {
      key: "track_inventory",
      label: "Track Inventory",
      type: "boolean"
    },
    {
      key: "inventory_count",
      label: "Inventory count",
      type: "number"
    },
    {
      key: "inventory_backorderable",
      label: "Inventory Backorderable",
      type: "boolean"
    },
    {
      key: "tax_category",
      label: "Tax category",
      type: "string"
    },
    {
      key: "tax_code",
      label: "Tax code",
      type: "string"
    },
    {
      key: "digital",
      label: "Digital",
      type: "boolean"
    },
    {
      key: "width",
      label: "Width",
      type: "number"
    },
    {
      key: "depth",
      label: "Depth",
      type: "number"
    },
    {
      key: "height",
      label: "Height",
      type: "number"
    },
    {
      key: "weight",
      label: "Weight",
      type: "number"
    },
    {
      key: "available_on",
      label: "Available on",
      type: "date"
    },
    {
      key: "discontinue_on",
      label: "Discontinue on",
      type: "date"
    },
    {
      key: "meta_title",
      label: "SEO Title",
      type: "string"
    },
    {
      key: "meta_description",
      label: "SEO Description",
      type: "string"
    },
    {
      key: "meta_keywords",
      label: "SEO Keywords",
      type: "string"
    },
    {
      key: "tags",
      label: "Tags",
      type: "string"
    },
    {
      key: "labels",
      label: "Labels",
      type: "string"
    },
    {
      key: "image1_src",
      label: "Image URL",
      type: "string"
    },
    {
      key: "image2_src",
      label: "Image URL #2",
      type: "string"
    },
    {
      key: "image3_src",
      label: "Image URL #3",
      type: "string"
    },
    {
      key: "option1_name",
      label: "Option #1 name",
      type: "string"
    },
    {
      key: "option1_value",
      label: "Option #1 value",
      type: "string"
    },
    {
      key: "option2_name",
      label: "Option #2 name",
      type: "string"
    },
    {
      key: "option2_value",
      label: "Option #2 value",
      type: "string"
    },
    {
      key: "option3_name",
      label: "Option #3 name",
      type: "string"
    },
    {
      key: "option3_value",
      label: "Option #3 value",
      type: "string"
    },
    {
      key: "category1",
      label: "Category #1",
      type: "string"
    },
    {
      key: "category2",
      label: "Category #2",
      type: "string"
    },
    {
      key: "category3",
      label: "Category #3",
      type: "string"
    }
  ]

  const propertiesCount = storeProductPropertiesCount < 20 ? 20 : storeProductPropertiesCount

  for (let n = 1; n <= propertiesCount; n++) {
    fields.push(
      {
        key: `property${n}_name`,
        label: `Property #${n} name`,
        type: "string"
      },
      {
        key: `property${n}_value`,
        label: `Property #${n} value`,
        type: "string"
      }
    )
  }

  return {
    name: "Products",
    sheets: [
      {
        name: 'Products',
        slug: 'products',
        fields: fields
      }
    ],
    actions: [
      {
        operation: "submitData",
        mode: "foreground",
        label: "Submit data",
        primary: true,
        constraints: [
          { type: 'hasData' }
        ]
      },
    ],
    settings: {
      track_changes: true
    }
  }
}
