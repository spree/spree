// TypeScript 7 ships no compiler API, which tsup calls to bundle type
// declarations. tsup asks for TypeScript as a peer, so it would get the
// workspace's 7; give it the version 6 twin, which provides the same API.
// Remove once tsup supports TypeScript 7.
function readPackage(pkg) {
  if (pkg.name === 'tsup') {
    delete pkg.peerDependencies?.typescript
    delete pkg.peerDependenciesMeta?.typescript
    pkg.dependencies = { ...pkg.dependencies, typescript: 'npm:@typescript/typescript6@^6.0.2' }
  }
  return pkg
}

module.exports = { hooks: { readPackage } }
