document.addEventListener('DOMContentLoaded', function() {
  // eslint-disable-next-line no-undef
  tinymce.init({
    selector: '.spree-rte',
    plugins: [
      'image table paste code link table'
    ],
    menubar: false,
    toolbar: 'undo redo | styleselect | bold italic link | alignleft aligncenter alignright alignjustify | table | bullist numlist outdent indent | code '
  });
})
