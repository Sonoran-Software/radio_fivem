# Developer Events

This document lists the server-side events emitted for developer integrations. Payload sketches use Lua table syntax. Unless noted, timestamps are Unix seconds from `os.time()`. All payloads are sanitized to contain only primitive values and shallow tables.

## Common Payload Shapes

- **Player Payload**
  ```
  {
      serverId = number,
      name = string?,
      identifiers = { string, ... }?,
      position = { x = number, y = number, z = number }?,
      heading = number?
  }
  ```
  Returned by `DeveloperEvents.playerContext`. `position`/`heading` are included when the underlying call requested coordinates.

- **Dispatcher Payload**
  ```
  {
      serverId = number,
      name = string?,
      phoneNumber = string?,
      identifiers = { string, ... }?
  }
  ```
  Specialised player payload that also embeds the dispatcher’s lb-phone number when available.

- **Callee Payload**
  ```
  {
      serverId = number?,
      name = string?,
      phoneNumber = string?,
      identifier = string?
  }
  ```
  Populated only when the lb-phone API exposes the remote party’s information.

- **Static Jammer Payload**
  ```
  {
      id = string?,
      name = string?,
      note = string?,
      type = 'static' | 'handheld' | string,
      range = number?,
      strength = number?,
      active = boolean,
      temporary = boolean?,
      owner = number?,
      position = { x = number?, y = number?, z = number?, heading = number?, exact = boolean? }?
  }
  ```

- **Handheld Jammer Payload**
  ```
  {
      id = string?,
      owner = number?,
      name = string?,
      range = number?,
      strength = number?,
      active = boolean
  }
  ```

## Dispatcher Redial Lifecycle

- `SonoranRadio::Developer:DispatcherRedial:Requested`
  - Fired when a dispatcher starts a redial request.
  - Payload: `dispatcher`, `context`
- `SonoranRadio::Developer:DispatcherRedial:Failed`
  - Emitted when a redial cannot be created (missing phone number, lb-phone offline, etc).
  - Payload: `dispatcher`, `context`, `reason`, `message`
- `SonoranRadio::Developer:DispatcherRedial:Started`
  - Indicates the lb-phone call was created successfully.
  - Payload: `dispatcher`, `context`, `callId`, `startedAt`
- `SonoranRadio::Developer:DispatcherRedial:Answered`
  - Emitted when the callee picks up.
  - Payload: `dispatcher`, `context`, `callId`, `callee?`, `answeredAt`, `call?`
- `SonoranRadio::Developer:DispatcherRedial:CancelRequested`
  - Fired as soon as the dispatcher manually cancels.
  - Payload: `dispatcher`, `context`, `callId`, `callee?`, `requestedAt`
- `SonoranRadio::Developer:DispatcherRedial:Ended`
  - Always emitted when the call fully terminates (hang-up, timeout, cancellation).
  - Payload: `dispatcher`, `context`, `callId`, `callee?`, `reason`, `startedAt`, `answeredAt?`, `endedAt`, `call?`

## Panic Button

- `SonoranRadio::Developer:Panic:Activated`
  - Fired when a user enables panic.
  - Payload:
    - `player` – player payload including coordinates/heading when available
    - `active` – always `true`
    - `updatedAt` – timestamp the server acknowledged the change
    - `metadata?` – sanitized metadata sent with the panic request (currently nil)
- `SonoranRadio::Developer:Panic:Cleared`
  - Emitted when panic is cleared by the user or implicitly (logout/cleanup).
  - Payload:
    - `player`
    - `active` – always `false`
    - `updatedAt`
    - `metadata?`
    - `reason?` – `'playerDropped'` when cleared because the player disconnected

## Radio State

- `SonoranRadio::Developer:RadioState:Updated`
  - Fired whenever a client publishes a new radio state snapshot.
  - Payload:
    - `player`
    - `state` – sanitized copy of the radio state table supplied by the client

## Jammer Lifecycle

- `SonoranRadio::Developer:Jammer:Spawned`
  - Static jammer placed via the build tools.
  - Payload: `player`, `jammer` (static payload), `metadata?`
- `SonoranRadio::Developer:Jammer:Moved`
  - Static/dynamic jammer repositioned.
  - Payload: `player`, `jammer`, `from?` (position), `to?` (position), `dynamic` (boolean)
- `SonoranRadio::Developer:Jammer:Deleted`
  - Jammer removed from the world.
  - Payload: `player`, `jammer`, `dynamic`
- `SonoranRadio::Developer:Jammer:PowerToggled`
  - Jammer power state flipped (static or dynamic).
  - Payload: `player`, `jammer`, `dynamic`
- `SonoranRadio::Developer:Jammer:HandheldActivated`
  - Handheld jammer equipped by a player.
  - Payload: `player`, `jammer` (handheld payload), `options?`
- `SonoranRadio::Developer:Jammer:HandheldDeactivated`
  - Handheld jammer unequipped or forcibly cleared.
  - Payload: `player`, `jammer` (handheld payload), `reason?` (`'playerDropped'` when cleanup triggered)
- `SonoranRadio::Developer:Jammer:HandheldPowerToggled`
  - Handheld jammer power state toggled while equipped.
  - Payload: `player`, `jammer`
- `SonoranRadio::Developer:Jammer:HandheldPlaced`
  - Equipped handheld placed on the ground as a temporary static jammer.
  - Payload: `player`, `handheld` (handheld payload prior to placement), `groundJammer` (static payload)
- `SonoranRadio::Developer:Jammer:HandheldDropped`
  - Handheld converted to a ground jammer via inventory drop recovery.
  - Payload: `player`, `handheld?`, `groundJammer`, `dropId?`
