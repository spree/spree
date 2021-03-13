// --- Dependencies
/** @jsx jsx */
import PropTypes from 'prop-types'
import { css, jsx } from '@emotion/core'
import kebabCase from 'lodash.kebabcase'

/**
 * Styles
 */

const styleToc = css`
  top: 100px;
  max-height: calc(100% - 120px);
  overflow-y: auto;
  overflow-x: hidden;
  margin-left: 51rem;
`

/**
 * Helpers
 */

const getSlugHref = text => `#${kebabCase(text)}`

const getMarginDepth = depth => ([1, 2].includes(depth) ? 0 : depth)

/**
 * Component
 */

const Toc = ({ headings }) => (
  <aside className="ml3 mw5 fixed dn db-l overflow-auto" css={styleToc}>
    <h3 className="mt0 mb1">Table Of Contents</h3>

    <nav>
      {headings.map(heading => {
        const title = heading.value.replace(/(<([^>]+)>)/gi, '')
        const slug = getSlugHref(title)
        const margin = `ml${getMarginDepth(heading.depth)}`

        if (heading.depth >= 4) return

        return (
          <a
            key={slug}
            className={`db gray hover-spree-green mb1 pointer link f6 ${margin}`}
            href={slug}
          >
            {title}
          </a>
        )
      })}
    </nav>
  </aside>
)

Toc.propTypes = {
  headings: PropTypes.arrayOf(
    PropTypes.shape({
      depth: PropTypes.number,
      value: PropTypes.string
    })
  )
}

export default Toc
