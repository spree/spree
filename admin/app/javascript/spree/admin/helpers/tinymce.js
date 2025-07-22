document.addEventListener('turbo:before-render', initializeTinmce)
document.addEventListener('turbo:load', initializeTinmce)
document.addEventListener('turbo:frame-render', initializeTinmce)

function initializeTinmce() {
  tinymce.remove()

  tinymce.init({
    content_style: 'body { font-family: Inter, sans-serif; font-size: 14px; }',
    selector: '.spree-rte',
    height: 300,
    extended_valid_elements: 'span',
    indent: false,
    plugins: ['image', 'table', 'code', 'link', 'lists'],
    menubar: false,
    inline_boundaries: false,
    toolbar: 'undo redo | formatselect | bold italic link forecolor backcolor | bullist numlist outdent indent | alignleft aligncenter alignright alignjustify | table | code',
    // Default styles without heading 1
    style_formats: [
      {
        title: 'Headings',
        items: [
          { title: 'Heading 2', format: 'h2' },
          { title: 'Heading 3', format: 'h3' },
          { title: 'Heading 4', format: 'h4' },
          { title: 'Heading 5', format: 'h5' },
          { title: 'Heading 6', format: 'h6' }
        ]
      },
      {
        title: 'Inline',
        items: [
          { title: 'Bold', format: 'bold' },
          { title: 'Italic', format: 'italic' },
          { title: 'Underline', format: 'underline' },
          { title: 'Strikethrough', format: 'strikethrough' },
          { title: 'Superscript', format: 'superscript' },
          { title: 'Subscript', format: 'subscript' },
          { title: 'Code', format: 'code' }
        ]
      },
      {
        title: 'Blocks',
        items: [
          { title: 'Paragraph', format: 'p' },
          { title: 'Blockquote', format: 'blockquote' },
          { title: 'Div', format: 'div' },
          { title: 'Pre', format: 'pre' }
        ]
      },
      {
        title: 'Align',
        items: [
          { title: 'Left', format: 'alignleft' },
          { title: 'Center', format: 'aligncenter' },
          { title: 'Right', format: 'alignright' },
          { title: 'Justify', format: 'alignjustify' }
        ]
      }
    ],
    setup: function (ed) {
      if (document.getElementById(ed.id).hasAttribute('readonly')) ed.mode.set('readonly')
    }
  })
}
