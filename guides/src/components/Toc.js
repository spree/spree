// --- Dependencies
/** @jsx jsx */
import PropTypes from 'prop-types'
import { css, jsx } from '@emotion/core'
import Slugger from 'github-slugger'

/**
 * Styles
 */

const styleToc = css`
  top: 140px;

  @media screen and (min-width: 60em) {
    & + article {
      margin-right: 16rem;
    }
  }
`

/**
 * Helpers
 */

const getSlugHref = string => {
  const slugger = new Slugger()

  return `#${slugger.slug(string)}`
}

const getMarginDepth = depth => ([1, 2].includes(depth) ? 0 : depth)

/**
 * Component
 */

const Toc = ({ headings }) => (
  <aside className="ml3 fixed w5 dn db-l overflow-auto right-0" css={styleToc}>
    <h4 className="ttu mt0 mb3">Table Of Contents</h4>

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
            {heading.value}
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
