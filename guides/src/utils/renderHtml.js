import remark from 'remark'
import html from 'remark-html'

const renderHtml = markdown => {
  let result = ''
  remark()
    .use(html)
    .process(markdown, (error, file) => {
      if (error) throw error
      result = file.contents
    })

  return result
}

export default renderHtml
