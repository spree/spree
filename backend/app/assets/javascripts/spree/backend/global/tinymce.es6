document.addEventListener('DOMContentLoaded', function() {
  // eslint-disable-next-line no-undef
  tinymce.init({
    selector: '.spree-rte',
    plugins: [
      'image table paste code'
    ],
    menubar: false,
    toolbar: 'undo redo | styleselect | bold italic | alignleft aligncenter alignright alignjustify | bullist numlist outdent indent | code '
  });
})
