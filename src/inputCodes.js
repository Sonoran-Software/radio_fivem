const mouseButtonCodes = {
    0: 'MouseClick.LeftClick',
    1: 'MouseClick.MiddleClick',
    2: 'MouseClick.RightClick',
    3: 'MouseClick.ExtraBtn1',
    4: 'MouseClick.ExtraBtn2',
};

function getInputCode(event) {
    return event.code || mouseButtonCodes[event.button];
}

function getPttInputCode(pttKeyName) {
    const specialKeyPrefix = 'SpecialKey.';
    return pttKeyName?.startsWith(specialKeyPrefix)
        ? pttKeyName.slice(specialKeyPrefix.length)
        : pttKeyName;
}

module.exports = { getInputCode, getPttInputCode };
