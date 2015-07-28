var path = require('path');
var pkg = require('../../package.json');

process.env.ATOM_NODE_VERSION = pkg.atomShellVersion

if (process.platform === 'win32') {
  process.env.ATOM_HOME = path.join(process.env.USERPROFILE, '.' + pkg.name);
} else {
  process.env.ATOM_HOME = path.join(process.env.HOME, '.' + pkg.name);
}
