'use strict';

// Source package entry point: absolute paths for Ada build tooling. The
// binding is Ada (GNAT + GPRbuild) and links the installed Polycall core
// (>= 1.1.0, binding ABI 1); this module loads nothing.
const path = require('node:path');

const fromPackageRoot = (...segments) => path.join(__dirname, ...segments);

module.exports = Object.freeze({
  root: __dirname,
  adaSpec: fromPackageRoot('src', 'ada_polycall.ads'),
  adaBody: fromPackageRoot('src', 'ada_polycall.adb'),
  project: fromPackageRoot('ada_polycall.gpr'),
  testProject: fromPackageRoot('tests', 'ada_polycall_tests.gpr'),
  config: fromPackageRoot('ada-polycallrc'),
  manifest: fromPackageRoot('polycall-binding.json'),
  license: fromPackageRoot('LICENSE')
});
