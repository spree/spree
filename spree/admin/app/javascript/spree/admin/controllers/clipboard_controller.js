import Clipboard from 'stimulus-clipboard'

export default class extends Clipboard {
  copy(event) {
    event.preventDefault()

    const text = this.sourceTarget.value || this.sourceTarget.innerHTML

    // https://stackoverflow.com/questions/73148190/copy-html-content-to-clipboard
    navigator.clipboard.write([new ClipboardItem({
      'text/plain': new Blob([text], {type: 'text/plain'}),
      'text/html': new Blob([text], {type: 'text/html'})
    })])

    this.copied()
  }
}
