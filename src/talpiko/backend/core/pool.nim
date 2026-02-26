# src/talpiko/backend/core/pool.nim
## Zero-overhead object pool for TpContext.
## Recycles context objects to eliminate per-request GC pressure.
##
## Design:
##   - Fixed-capacity ring of pre-allocated TpContext ref objects
##   - Bitmask of free slots for O(1) acquire/release
##   - Thread-local by default (no locking overhead)
##   - Capacity configured via `tpPoolSize` compile-time constant

import tables, locks
import httpcore

# ── Compile-time pool size ───────────────────────────────────────────────────

const tpPoolSize* {.intdefine.} = 64
  ## Number of pre-allocated contexts in the pool.
  ## Override via: -d:tpPoolSize=128

# ── Pool types ───────────────────────────────────────────────────────────────

type
  TpPoolBitset = array[(tpPoolSize + 63) div 64, uint64]
    ## Compact free-slot bitmap. Each bit = 1 means the slot is free.

  TpContextPool*[T] = object
    ## Generic fixed-size object pool.
    ## T must have a `reset(obj: T)` proc for cleanup between uses.
    slots: array[tpPoolSize, T]
    free: TpPoolBitset
    count: int   # number of free slots remaining

# ── Bitmap helpers ───────────────────────────────────────────────────────────

proc setBit(bs: var TpPoolBitset, idx: int) {.inline.} =
  bs[idx shr 6] = bs[idx shr 6] or (1'u64 shl (idx and 63))

proc clearBit(bs: var TpPoolBitset, idx: int) {.inline.} =
  bs[idx shr 6] = bs[idx shr 6] and not (1'u64 shl (idx and 63))

proc findFreeSlot(bs: TpPoolBitset): int {.inline.} =
  ## Returns the first free slot index, or -1 if all occupied.
  for i in 0 ..< bs.len:
    if bs[i] != 0:
      # Trailing-zero count to find lowest set bit
      var mask = bs[i]
      var bit = 0
      while (mask and 1) == 0:
        mask = mask shr 1
        inc(bit)
      return i * 64 + bit
  return -1

# ── Pool init ────────────────────────────────────────────────────────────────

proc initPool*[T](pool: var TpContextPool[T], initProc: proc(): T) =
  ## Initialises all slots by calling `initProc` for each.
  for i in 0 ..< tpPoolSize:
    pool.slots[i] = initProc()
    pool.free.setBit(i)
  pool.count = tpPoolSize

# ── Acquire / Release ────────────────────────────────────────────────────────

proc acquire*[T](pool: var TpContextPool[T]): ptr T =
  ## Returns a pointer to a free slot, or `nil` if the pool is exhausted.
  ## Complexity: O(capacity / 64) — effectively O(1) for tpPoolSize ≤ 512.
  let idx = pool.free.findFreeSlot()
  if idx < 0 or idx >= tpPoolSize:
    return nil
  pool.free.clearBit(idx)
  dec(pool.count)
  return addr pool.slots[idx]

proc release*[T](pool: var TpContextPool[T], p: ptr T, resetProc: proc(obj: var T)) =
  ## Returns a slot back to the pool and resets its state.
  ## `p` must have been acquired from this pool.
  let idx = cast[int](p) - cast[int](addr pool.slots[0])
  let slotIdx = idx div sizeof(T)
  if slotIdx >= 0 and slotIdx < tpPoolSize:
    resetProc(pool.slots[slotIdx])
    pool.free.setBit(slotIdx)
    inc(pool.count)

proc freeCount*[T](pool: TpContextPool[T]): int {.inline.} =
  ## Returns the number of currently available slots.
  pool.count
