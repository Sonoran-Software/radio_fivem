const assert = require('node:assert/strict');
const fs = require('node:fs');
const { tmpdir } = require('node:os');
const { join, resolve } = require('node:path');
const { test } = require('node:test');
const { runInNewContext } = require('node:vm');

function verifyManagedCache(t, exportName, fileName) {
    const folder = fs.mkdtempSync(join(tmpdir(), 'radio-fivem-config-'));
    const file = join(folder, fileName);
    t.after(() => {
        if (fs.existsSync(file)) fs.unlinkSync(file);
        fs.rmdirSync(folder);
    });
    const resource = 'sonoranradio';
    let invokingResource = resource;
    let interruptRename = false;
    const runtimeFs = {
        ...fs,
        renameSync(from, to) {
            if (interruptRename) throw new Error('Simulated filesystem failure');
            fs.renameSync(from, to);
        },
    };
    const registered = {};
    const script = resolve(__dirname, '../lua/utils.js');
    runInNewContext(fs.readFileSync(script, 'utf8'), {
        require: (name) => name === 'fs' ? runtimeFs : require(name),
        exports: (name, fn) => { registered[name] = fn; },
        GetCurrentResourceName: () => resource,
        GetInvokingResource: () => invokingResource,
        GetResourcePath: () => folder,
        Buffer,
    }, { filename: script });

    const save = registered[exportName];
    assert.equal(save('{"revision":1}'), true);
    invokingResource = 'unrelated';
    assert.equal(save('{"revision":2}'), false);
    invokingResource = resource;
    interruptRename = true;
    assert.equal(save('{"revision":2}'), false);
    assert.equal(fs.readFileSync(file, 'utf8'), '{"revision":1}');
    assert.deepEqual(fs.readdirSync(folder), [fileName]);
    interruptRename = false;
    assert.equal(save('{"revision":2}'), true);
    assert.equal(fs.readFileSync(file, 'utf8'), '{"revision":2}');
}

test('managed settings cache is replaced atomically by its owning resource', (t) =>
    verifyManagedCache(t, 'SaveManagedRadioSettings', 'sonoranradio-settings.json'));

test('managed placements cache is replaced atomically by its owning resource', (t) =>
    verifyManagedCache(t, 'SaveManagedRadioPlacements', 'sonoranradio-placements.json'));
