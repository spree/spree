// --- Dependencies
import * as React from 'react'
import PropTypes from 'prop-types'

// --- Icons
import IconEdit from 'react-feather/dist/icons/edit-2'

/**
 * Component
 */

export default function MarkdownPageFooter({ group, isIndex, section, title }) {
  const baseUrl =
    'https://github.com/spree/spree/edit/master/guides/src/content'
  const edge = group
    .find(el => el.section === section)
    .edges.find(el => el.node.frontmatter.title === title)

  if (!edge) {
    return null
  }

  const pathname = edge.node.fields.slug.replace('.html', '')
  const url = `${baseUrl}${pathname}${isIndex ? 'index' : ''}.md`
  return (
    <a
      href={url}
      className="dib mv2 mv0-l link mr0 f5 nowrap pv2 ph2 bg-light-gray fw6 br2"
      target="_blank"
    >
      <IconEdit className="pointer dark-gray v-btm mr2 w1" />
      <span className="dark-gray">Edit this page on GitHub</span>
    </a>
  )
}

MarkdownPageFooter.propTypes = {
  section: PropTypes.string.isRequired,
  title: PropTypes.string.isRequired,
  group: PropTypes.array.isRequired,
  isIndex: PropTypes.bool.isRequired
}
