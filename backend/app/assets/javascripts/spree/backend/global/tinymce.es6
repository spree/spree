/* eslint-disable no-undef */
document.addEventListener('DOMContentLoaded', function() {
  tinymce.init({
    selector: '.spree-rte',
    images_upload_handler: functionName,
    plugins: [
      'image table paste code link table'
    ],
    menubar: false,
    toolbar: 'undo redo | styleselect | bold italic link forecolor backcolor | alignleft aligncenter alignright alignjustify | table | bullist numlist outdent indent | code image'
  })
})

function functionName(blobInfo, success) {
  const formData = new FormData()
  formData.append('file', blobInfo.blob(), blobInfo.filename())

  const requestData = {
    uri: `${Spree.routes.images_api_v2}/upload`,
    method: 'POST',
    dataBody: formData,
    formatDataBody: false
  }
  spreeFetchRequest(requestData, formatReturnDataForTinyMce)

  function formatReturnDataForTinyMce (data) {
    success(data.location)
  }
}
