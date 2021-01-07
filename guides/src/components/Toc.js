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
  border-radius: 6px;
  padding: 0.5em 1em;
  background: #f4f4f4;

  @media screen and (min-width: 60em) {
    & + article {
      margin-right: 16rem;
    }
  }
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
  <aside className="ml3 mw5 fixed dn db-l overflow-auto right-1" css={styleToc}>
    <h3 className="mt0 mb1">Table Of Contents</h3>

    <nav>
      {headings.map(heading => {
        const slug = getSlugHref(heading.value)
        const margin = `ml${getMarginDepth(heading.depth)}`

        if (heading.depth >= 4) return

        return (
          <a
            key={slug}
            className={`db gray hover-spree-green mb1 pointer link ${margin}`}
            href={slug}
          >
            <span dangerouslySetInnerHTML={{ __html: heading.value }} />
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
