// Executes the pure ArkTS business tests on Node; UI/device tests still require HarmonyOS.
const fs = require('node:fs');
const path = require('node:path');
const Module = require('node:module');
const assert = require('node:assert/strict');
const { test } = require('node:test');

const compilerPath = process.env.TYPESCRIPT_PATH;
if (!compilerPath) {
  throw new Error('Set TYPESCRIPT_PATH to your DevEco TypeScript lib/typescript.js.');
}
const ts = require(compilerPath);
const root = path.resolve(__dirname, '..');
const originalLoad = Module._load;
const pending = [];

// This adapter runs the same assertions as Hypium; it does not emulate platform APIs.
const hypium = {
  describe: (_name, body) => body(),
  it: (name, _flags, body) => pending.push({ name, body }),
  expect: (actual) => ({
    assertEqual: (expected) => assert.strictEqual(actual, expected),
    assertTrue: () => assert.strictEqual(actual, true),
    assertFalse: () => assert.strictEqual(actual, false),
  }),
};
Module._load = function (name, parent, isMain) {
  if (name === '@ohos/hypium') return hypium;
  return originalLoad.call(this, name, parent, isMain);
};
Module._extensions['.ets'] = function (module, filename) {
  const source = fs.readFileSync(filename, 'utf8');
  const result = ts.transpileModule(source, {
    fileName: filename.replace(/\.ets$/, '.ts'),
    compilerOptions: { target: ts.ScriptTarget.ES2021, module: ts.ModuleKind.CommonJS },
    reportDiagnostics: true,
  });
  const errors = (result.diagnostics || []).filter(d => d.category === ts.DiagnosticCategory.Error);
  assert.equal(errors.length, 0, errors.map(d => ts.flattenDiagnosticMessageText(d.messageText, '\n')).join('\n'));
  module._compile(result.outputText, filename);
};

require(path.join(root, 'entry/src/test/RecipeSearch.test.ets')).default();
for (const item of pending) test(item.name, item.body);
