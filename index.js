'use strict';

const path = require('node:path');

const fromPackageRoot = (...segments) => path.join(__dirname, ...segments);

module.exports = Object.freeze({
  root: __dirname,
  adaSpec: fromPackageRoot('src', 'ada_polycall.ads'),
  adaBody: fromPackageRoot('src', 'ada_polycall.adb'),
  nativeAdapter: fromPackageRoot('src', 'ada_polycall.c'),
  publicHeader: fromPackageRoot('include', 'ada_polycall.h'),
  ffiHeader: fromPackageRoot('generated', 'polycall', 'polycall_ffi.h'),
  project: fromPackageRoot('ada_polycall.gpr'),
  config: fromPackageRoot('ada-polycallrc'),
  manifest: fromPackageRoot('polycall-binding.json')
});
