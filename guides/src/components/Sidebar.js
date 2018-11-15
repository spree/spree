import * as React from 'react'
import PropTypes from 'prop-types'
import { Link } from 'gatsby'

const Sidebar = ({ nav }) => (
  <aside>
    <nav>
      <ul className="list ma0 pl0">
        {nav.map((item, index) => (
          <li key={index}>
            <h3>
              <span className="ttc">
                {item.section.split('/').length > 1
                  ? item.section.split('/')[1]
                  : item.section.split('/')[0]}
              </span>
            </h3>
            <ul>
              {item.edges.map((edge, index) => (
                <li key={index}>
                  <Link
                    to={edge.node.relativePath.replace('.md', '.html')}
                    className="link gray db mv1"
                    activeClassName="green"
                  >
                    {edge.node.childMarkdownRemark.frontmatter.title}
                  </Link>
                </li>
              ))}
            </ul>
          </li>
        ))}
      </ul>
    </nav>
  </aside>
)

Sidebar.propTypes = {
  nav: PropTypes.array.isRequired
}

export default Sidebar
