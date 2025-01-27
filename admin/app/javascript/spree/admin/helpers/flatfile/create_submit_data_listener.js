import { FlatfileListener } from "@flatfile/listener"
import api from "@flatfile/api";
import { post } from '@rails/request.js'
import { DirectUpload } from "@rails/activestorage"

export default function createSubmitDataListener(kind) {
  return FlatfileListener.create((listener) => {
    listener.on(
      "job:ready",
      { job: "workbook:submitData" },
      async (event) => {
        const { jobId, workbookId } = event.context
        const { data: workbookSheets } = await api.sheets.list({ workbookId })

        const sheet = workbookSheets[0]
        const { data: recordsData } = await api.records.get(sheet.id);

        try {
          await api.jobs.ack(jobId, { info: "Submitting data...", progress: 10 })

          const file = new File([JSON.stringify(recordsData)], 'products-file', { type: "application/json" })
          const directUploadUrl = document.querySelector("meta[name='direct-upload-url']").getAttribute("content")

          const upload = new DirectUpload(file, directUploadUrl)

          upload.create(async (error, blob) => {
            if (error) {
              console.error(error)
              await api.jobs.fail(jobId, { outcome: { message: error } })
            } else {
              const response = await post('/admin/imports', {
                body: JSON.stringify({
                  kind: kind,
                  file: blob.signed_id
                }),
                contentType: 'application/json',
                responseKind: 'json'
              })

              const responseBody = await response.json

              if (response.ok) {
                await api.jobs.complete(jobId, { outcome: { message: "Data submitted! Redirecting..." } })
                setTimeout(() => window.location.href = responseBody.import_url, 3000)
              } else {
                throw new Error(`An error occurred: ${responseBody.errors}`)
              }
            }
          })
        } catch (error) {
          console.error(error)
          await api.jobs.fail(jobId, { outcome: { message: error.message } })
        }
      }
    )
  })
}
