const assert = require('assert');
const { getInputCode, getPttInputCode } = require('../src/inputCodes');

assert.strictEqual(getInputCode({ code: 'Backslash' }), 'Backslash');
assert.strictEqual(getInputCode({ button: 3 }), 'MouseClick.ExtraBtn1');
assert.strictEqual(getInputCode({ button: 4 }), 'MouseClick.ExtraBtn2');
assert.strictEqual(getPttInputCode('SpecialKey.F8'), 'F8');
assert.strictEqual(
    getPttInputCode('SpecialKey.MouseClick.ExtraBtn1'),
    'MouseClick.ExtraBtn1',
);

console.log('input code tests passed');
