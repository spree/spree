document.addEventListener('DOMContentLoaded', function() {
  // eslint-disable-next-line no-undef
  tinymce.init({
    selector: '.spree-rte',
    plugins: [
      'image table paste code link'
    ],
    menubar: false,
    toolbar: 'undo redo | styleselect | bold italic link | alignleft aligncenter alignright alignjustify | bullist numlist outdent indent | code '
  });
})
