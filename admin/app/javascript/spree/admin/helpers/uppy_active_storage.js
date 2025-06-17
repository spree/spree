/* eslint-disable no-undef */
import BasePlugin from "@uppy/core/lib/BasePlugin.js"
import { createId } from "@paralleldrive/cuid2"
// const Translator = require('@uppy/utils/lib/Translator');
// const { Provider, Socket } = require('@uppy/companion-client');
// const emitSocketProgress = require('@uppy/utils/lib/emitSocketProgress');
// const getSocketHost = require('@uppy/utils/lib/getSocketHost');
import { RateLimitedQueue } from '@uppy/utils/lib/RateLimitedQueue'
import { DirectUpload } from "@rails/activestorage"

export default class ActiveStorageUpload extends BasePlugin {
  constructor(uppy, opts) {
    super(uppy, opts)

    this.id = opts.id || "ActiveStorageUpload"
    this.title = opts.title || "ActiveStorageUpload"
    this.type = "uploader"

    const defaultOptions = {
      limit: 0,
      timeout: 30 * 1000,
      directUploadUrl: null,
      headers: {},
      crop: false
    }

    this.opts = Object.assign({}, defaultOptions, opts)

    // Simultaneous upload limiting is shared across all uploads with this plugin.
    if (typeof this.opts.limit === "number" && this.opts.limit !== 0) {
      this.limitUploads = new RateLimitedQueue(this.opts.limit)
    } else {
      this.limitUploads = fn => fn
    }

    this.handleUpload = this.handleUpload.bind(this)
  }

  install() {
    this.uppy.addUploader(this.handleUpload)
    this.uppy.on('file-editor:complete', this.onEditorComplete)
  }

  uninstall() {
    this.uppy.removeUploader(this.handleUpload)
    this.uppy.off('file-editor:complete', this.onEditorComplete)
  }
  
  onEditorComplete = (updatedFile) => {
    this.handleUpload([updatedFile.id])

    // call directly upload method after editing image
    return this.uploadFiles([updatedFile])
  }

  handleUpload(fileIDs) {
    if (fileIDs.length === 0) {
      this.uppy.log("[ActiveStorage] No files to upload!")
      return Promise.resolve()
    }
    // do not upload before editing is done
    if (this.opts.crop) {
      return Promise.resolve()
    }

    this.uppy.log("[ActiveStorage] Uploading...")
    const files = fileIDs.map(fileID => this.uppy.getFile(fileID))

    return this.uploadFiles(files).then(() => null)
  }

  upload(file, current, total) {
    this.uppy.log(`uploading ${current} of ${total}`)

    return new Promise((resolve, reject) => {
      const timer = this.createProgressTimeout(this.opts.timeout, error => {
        //xhr.abort();
        this.uppy.emit("upload-error", file, error)
        reject(error)
      })

      var directHandlers = {
        directUploadWillStoreFileWithXHR: null,
        directUploadDidProgress: null,
      }
      directHandlers.directUploadDidProgress = ev => {
        this.uppy.log(`[XHRUpload] ${id} progress: ${ev.loaded} / ${ev.total}`)
        timer.progress()

        if (ev.lengthComputable) {
          this.uppy.emit("upload-progress", file, {
            uploader: this,
            bytesUploaded: ev.loaded,
            bytesTotal: ev.total,
          })
        }
      }
      directHandlers.directUploadWillStoreFileWithXHR = request => {
        request.upload.addEventListener("progress", event =>
          directHandlers.directUploadDidProgress(event)
        )
      }

      const { data, meta } = file

      if (!data.name && meta.name) {
        data.name = meta.name
      }

      const upload = new DirectUpload(data, this.opts.directUploadUrl, directHandlers, this.opts.headers);
      const id = createId()

      upload.create((error, blob) => {
        this.uppy.log(`[XHRUpload] ${id} finished`)
        timer.done()

        if (error) {
          const response = {
            status: "error",
          }

          this.uppy.setFileState(file.id, { response })

          this.uppy.emit("upload-error", file, error)
          return reject(error)
        } else {
          const response = {
            status: "success",
            directUploadSignedId: blob.signed_id,
          }

          this.uppy.emit("upload-success", file, blob)

          return resolve(file)
        }
      })

      this.uppy.on("file-removed", removedFile => {
        if (removedFile.id === file.id) {
          timer.done()
          upload.abort && upload.abort()
        }
      })

      this.uppy.on("upload-cancel", fileID => {
        if (fileID === file.id) {
          timer.done()
          upload.abort && upload.abort()
        }
      })

      this.uppy.on("cancel-all", () => {
        timer.done()
        upload.abort && upload.abort()
      })
    })
  }

  uploadFiles(files) {
    const actions = files.map((file, i) => {
      const current = parseInt(i, 10) + 1
      const total = files.length

      if (file.error) {
        return () => Promise.reject(new Error(file.error))
      } else {
        this.uppy.emit("upload-start", [file])
        return this.upload.bind(this, file, current, total)
      }
    })

    const promises = actions.map(action => {
      const limitedAction = this.limitUploads(action)
      return limitedAction()
    })

    return Promise.allSettled(promises)
  }

  // Helper to abort upload requests if there has not been any progress for `timeout` ms.
  // Create an instance using `timer = createProgressTimeout(10000, onTimeout)`
  // Call `timer.progress()` to signal that there has been progress of any kind.
  // Call `timer.done()` when the upload has completed.
  createProgressTimeout(timeout, timeoutHandler) {
    const uppy = this.uppy
    const self = this
    let isDone = false

    function onTimedOut() {
      uppy.log("[XHRUpload] timed out")
      const error = new Error(self.i18n("timedOut", { seconds: Math.ceil(timeout / 1000) }))
      timeoutHandler(error)
    }

    let aliveTimer = null
    function progress() {
      // Some browsers fire another progress event when the upload is
      // cancelled, so we have to ignore progress after the timer was
      // told to stop.
      if (isDone) return

      if (timeout > 0) {
        if (aliveTimer) clearTimeout(aliveTimer)
        aliveTimer = setTimeout(onTimedOut, timeout)
      }
    }

    function done() {
      uppy.log("[XHRUpload] timer done")
      if (aliveTimer) {
        clearTimeout(aliveTimer)
        aliveTimer = null
      }
      isDone = true
    }

    return {
      progress,
      done,
    }
  }
}
