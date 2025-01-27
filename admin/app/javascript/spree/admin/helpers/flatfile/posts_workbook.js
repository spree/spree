export const postsWorkbook = {
  name: "Posts",
  sheets: [
    {
      name: 'Posts',
      slug: 'posts',
      fields: [
        {
          key: "slug",
          label: "Slug",
          type: "string",
          constraints: [
            { type: "required" }
          ]
        },
        {
          key: "title",
          label: "Title",
          type: "string",
          constraints: [
            { type: "required" }
          ]
        },
        {
          key: "excerpt",
          label: "Excerpt",
          type: "string"
        },
        {
          key: "content",
          label: "Content",
          type: "string"
        },
        {
          key: "image_url",
          label: "Image URL",
          type: "string"
        },
        {
          key: "published_at",
          label: "Published at",
          type: "date"
        },
        {
          key: "post_category_name",
          label: "Category name",
          type: "string"
        },
        {
          key: "post_category_slug",
          label: "Category slug",
          type: "string"
        },
        {
          key: "meta_title",
          label: "Meta title",
          type: "string"
        },
        {
          key: "meta_description",
          label: "Meta description",
          type: "string"
        }
      ]
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
