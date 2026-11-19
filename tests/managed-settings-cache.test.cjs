const assert = require('node:assert/strict');
const fs = require('node:fs');
const { tmpdir } = require('node:os');
const { join, resolve } = require('node:path');
const { test } = require('node:test');
const { runInNewContext } = require('node:vm');

function loadFileExports(folder, runtimeFs, invokingResource) {
    const registered = {};
    const script = resolve(__dirname, '../lua/utils.js');
    runInNewContext(fs.readFileSync(script, 'utf8'), {
        require: (name) => name === 'fs' ? runtimeFs : require(name),
        exports: (name, fn) => { registered[name] = fn; },
        GetCurrentResourceName: () => 'sonoranradio',
        GetInvokingResource: invokingResource,
        GetResourcePath: () => folder,
        Buffer,
    }, { filename: script });
    return registered;
}

test('managed config backup is replaced atomically by its owning resource', (t) => {
    const folder = fs.mkdtempSync(join(tmpdir(), 'radio-fivem-config-'));
    const configDirectory = join(folder, 'lua', 'config');
    const fileName = '.configuration-cache.json';
    const file = join(configDirectory, fileName);
    fs.mkdirSync(configDirectory, { recursive: true });
    t.after(() => {
        if (fs.existsSync(file)) fs.unlinkSync(file);
        fs.rmdirSync(configDirectory);
        fs.rmdirSync(join(folder, 'lua'));
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
    const save = loadFileExports(folder, runtimeFs, () => invokingResource).WriteManagedRadioConfigBackup;
    assert.equal(save('{"revision":1}'), true);
    invokingResource = 'unrelated';
    assert.equal(save('{"revision":2}'), false);
    invokingResource = resource;
    interruptRename = true;
    assert.equal(save('{"revision":2}'), false);
    assert.equal(fs.readFileSync(file, 'utf8'), '{"revision":1}');
    assert.deepEqual(fs.readdirSync(configDirectory), [fileName]);
    interruptRename = false;
    assert.equal(save('{"revision":2}'), true);
    assert.equal(fs.readFileSync(file, 'utf8'), '{"revision":2}');
});

test('migration archives only legacy files and can retry a permissions failure', (t) => {
    const folder = fs.mkdtempSync(join(tmpdir(), 'radio-fivem-migration-'));
    const configDirectory = join(folder, 'lua', 'config');
    const configFile = join(folder, 'config.lua');
    const towers = join(folder, 'towers.json');
    const scanners = join(folder, 'scanners.DEFAULT.json');
    const version = join(folder, 'version.json');
    const original = 'Config = { chatter = true }\n';
    const bootstrap = 'Config = {}\nConfig.comId = "TEST"\nConfig.apiKey = "secret"\nConfig.serverId = 3\n';
    fs.mkdirSync(configDirectory, { recursive: true });
    fs.writeFileSync(configFile, original);
    fs.writeFileSync(towers, '[]');
    fs.writeFileSync(scanners, '[]');
    fs.writeFileSync(version, '{}');
    t.after(() => {
        for (const name of fs.readdirSync(configDirectory)) {
            const archive = join(configDirectory, name);
            for (const archivedFile of fs.readdirSync(archive)) fs.unlinkSync(join(archive, archivedFile));
            fs.rmdirSync(archive);
        }
        for (const file of [configFile, towers, scanners, version]) {
            if (fs.existsSync(file)) fs.unlinkSync(file);
        }
        fs.rmdirSync(configDirectory);
        fs.rmdirSync(join(folder, 'lua'));
        fs.rmdirSync(folder);
    });

    let failRewrite = true;
    let failScannerMove = true;
    const runtimeFs = {
        ...fs,
        renameSync(from, to) {
            if ((failRewrite && to === configFile) || (failScannerMove && from === scanners)) {
                throw new Error('Simulated permissions failure');
            }
            fs.renameSync(from, to);
        },
    };
    const clean = loadFileExports(folder, runtimeFs, () => 'sonoranradio').ArchiveMigratedRadioConfig;
    assert.equal(clean('changed since read', bootstrap), false);
    assert.equal(clean(original, bootstrap), false);
    assert.equal(fs.readFileSync(configFile, 'utf8'), original);
    assert.equal(fs.existsSync(towers), true);

    failRewrite = false;
    assert.equal(clean(original, bootstrap), false);
    assert.equal(fs.readFileSync(configFile, 'utf8'), bootstrap);
    assert.equal(fs.existsSync(towers), false);
    assert.equal(fs.existsSync(scanners), true);
    failScannerMove = false;
    assert.equal(clean(bootstrap, bootstrap), true);
    const archives = fs.readdirSync(configDirectory).map((name) => join(configDirectory, name));
    for (const [name, contents] of [['config.lua', original], ['towers.json', '[]'], ['scanners.DEFAULT.json', '[]']]) {
        assert.ok(archives.some((dir) => fs.existsSync(join(dir, name)) && fs.readFileSync(join(dir, name), 'utf8') === contents));
    }
    assert.equal(fs.readFileSync(version, 'utf8'), '{}');
    assert.equal(fs.existsSync(scanners), false);
    assert.equal(clean(bootstrap, bootstrap), true);
    assert.equal(fs.readdirSync(configDirectory).length, archives.length);
});
