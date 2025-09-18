# Index Sharding Implementation Guide

**Version:** 0.10.0-draft
**Last Updated:** September 2025
**Status:** Draft Specification

This document provides detailed implementation guidance for the sharding algorithms used in the solid-crdt-sync indexing layer. For architectural overview, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Sharding Algorithm Details

### Resource Assignment to Shards

When a new resource is created or an existing resource is updated, the framework determines which shard should contain its index entry using the configured sharding algorithm:

```
1. Extract resource IRI: https://alice.podprovider.org/data/recipes/tomato-soup
2. Apply hash function: md5("https://alice.podprovider.org/data/recipes/tomato-soup") → 5d41402abc4b2a76b9719d911017c592
3. Convert to integer: Take first 8 hex chars → 0x5d41402a → 1564917802
4. Calculate modulo: 1564917802 % 2 = 0
5. Assign to shard: shard-0
```

### Consistency Guarantees

- The same resource always maps to the same shard (deterministic)
- Resources are distributed roughly evenly across shards  
- Shard count changes use lazy, client-side rebalancing

## Client-Side Shard Evolution

In Solid's decentralized context, users are not system administrators and cannot perform traditional "maintenance operations." Instead, shard count changes are handled as application upgrades with lazy migration:

### Automatic and Manual Shard Changes

1. **System defaults:** Framework defaults to `v1_0_0` and single shard, library authors should make these explicit in index creation
2. **Developer override (if needed):** Developer can specify major version for breaking changes (e.g., `v2_0_0`)
3. **Automatic scaling:** System increases shard count when any active shard exceeds threshold (e.g., 1000 entries)
4. **Natural progression:** 1 → 2 → 4 → 8 → 16 shards as data grows
5. **Version auto-increment:** System automatically increments middle number: `v1_0_0` → `v1_1_0` → `v1_2_0` for shard scaling
6. **Gradual deployment:** Updated configurations coexist during lazy migration period
7. **Lazy migration:** Existing entries migrate opportunistically during normal operations

### Lazy Migration Process

```turtle
# Index configuration shows current sharding algorithm  
<https://alice.podprovider.org/indices/recipes/index-full-a1b2c3d4/index>
  idx:shardingAlgorithm [
    a idx:ModuloHashSharding ;
    idx:hashAlgorithm "md5" ;
    idx:numberOfShards 4 ;           # Current configuration (auto-scaled from 1)
    idx:configVersion "1_2_0" ;      # Default v1, auto-scale 2 (1→2→4), conflict 0
    idx:autoScaleThreshold 1000      # Framework default threshold
  ] ;
  idx:hasShard 
    # Evolution: single shard → 2 shards → 4 shards
    # Legacy: <shard-mod-md5-1-0-v1_0_0> (migrated out, tombstoned)
    # Legacy: <shard-mod-md5-2-0-v1_1_0>, <shard-mod-md5-2-1-v1_1_0> (migrated out)
    # Current shards (4-shard configuration) 
    <shard-mod-md5-4-0-v1_2_0>, <shard-mod-md5-4-1-v1_2_0>, 
    <shard-mod-md5-4-2-v1_2_0>, <shard-mod-md5-4-3-v1_2_0> .
```

### Recommended Library Implementation

```turtle
# When library creates new index, explicitly write defaults:
<https://alice.podprovider.org/indices/recipes/index-full-a1b2c3d4/index>
  idx:shardingAlgorithm [
    a idx:ModuloHashSharding ;
    idx:hashAlgorithm "md5" ;
    idx:numberOfShards 1 ;           # Explicit default
    idx:configVersion "1_0_0" ;      # Explicit default  
    idx:autoScaleThreshold 1000      # Explicit default
  ] ;
  idx:hasShard <shard-mod-md5-1-0-v1_0_0> .
```

## Automatic Scaling Algorithm

1. **Monitor shard sizes:** During writes and sync, track entry counts in active shards
2. **Trigger scaling:** When any shard exceeds `idx:autoScaleThreshold` entries (e.g., 1000)
3. **Calculate new shard count:** Double current count (1→2→4→8→16) or use configured algorithm  
4. **Auto-increment version:** Increment scale component: `v1_0_0` → `v1_1_0` → `v1_2_0`
5. **Begin lazy migration:** Start using new shards for new entries, migrate opportunistically

## Self-Describing Shard Names

- **Format:** `shard-{algorithm}-{hash}-{totalShards}-{shardNumber}-v{major}_{scale}_{conflict}`
- **Example:** `shard-mod-md5-4-0-v1_2_0` = modulo, md5, 4 shards, shard #0, dev version 1, auto-scale version 2, conflict resolution 0
- **Version Components:**
  - `major`: Developer-controlled version (increment for breaking changes)
  - `scale`: Auto-increment when system increases shard count due to size thresholds
  - `conflict`: Auto-increment for 2P-Set conflict resolution during cycles
- **Benefits:** Fully automated scaling with deterministic conflict resolution

## Migration Implementation

### Migration Triggers (Opportunistic)

- **During writes:** New/updated resources use current shard count, migrate existing entry if found in different shard
- **During sync:** If index entry found in non-current shard, opportunistically migrate to correct shard  
- **During cleanup (optional):** Future versions may implement background migration during idle time

### Migration Process Details

- **"Migrate" means:** Add entry to correct shard (using 2P-Set add), remove from incorrect shard (using 2P-Set remove)  
- **Empty shard cleanup:** When a shard becomes empty, remove it from `idx:hasShard` list (using 2P-Set remove with tombstone)
- **New installations:** Only sync shards currently listed in `idx:hasShard` - avoid downloading empty legacy shards
- **Configuration cycles:** 2→4→2 cycles work: `v1_1_0` (2 shards) → `v1_2_0` (4 shards) → `v1_3_0` (2 shards). Each version gets unique shard names avoiding 2P-Set conflicts
- **Version conflict resolution:** If attempting to add a shard name that exists in tombstones, automatically increment to next available version (e.g., v2_0_0 → v2_0_1)

### Client-Side Constraints

- **Limited execution time:** Migration happens in small batches to respect mobile background limits
- **Concurrent access:** Multiple installations may migrate simultaneously - use CRDT merge rules for conflicts
- **Never "finished":** Accept that some entries may remain in non-current shards indefinitely  
- **Graceful lookup:** Check all active shards in `idx:hasShard` list (empty shards are automatically tombstoned)

**Example migration:** Resource `tomato-soup` with hash `...1112` starts in legacy `shard-mod-md5-2-0-v1` (1112 % 2 = 0), eventually migrates to new `shard-mod-md5-4-0-v2` (1112 % 4 = 0) when accessed.

## Index Entry Conflict Resolution

Index entries within shards use **LWW-Register (Last Writer Wins)** for all properties, providing simple and predictable conflict resolution during shard merging and updates.

### CRDT Merge Behavior

**All Properties Use LWW-Register:**
- **Header properties** (e.g., `schema:name`, `schema:dateCreated`): Last writer wins
- **Clock hash metadata** (e.g., `crdt:clockHash`): Last writer wins  
- **Resource references** (e.g., `idx:resource`): Last writer wins

**Rationale for Uniform LWW-Register:**
- **Architectural simplicity**: No complex mapping file inheritance from indexed resource types
- **Performance focus**: Index entries are cached data for efficiency, not authoritative sources
- **Self-healing**: Inconsistencies can be resolved by regenerating from authoritative resources
- **Predictable semantics**: "Most recent update wins" is deterministic across installations

### Conflict Resolution Examples

**Scenario 1: Header Property Update**
```turtle
# Installation A updates recipe title in index
<idx:entry-123> schema:name "Updated Recipe Title" ;
                crdt:clockEntry [...timestamp: T1...] .

# Installation B updates same entry simultaneously  
<idx:entry-123> schema:name "Different Recipe Title" ;
                crdt:clockEntry [...timestamp: T2...] .

# Result: Entry with latest timestamp wins (T2 > T1)
<idx:entry-123> schema:name "Different Recipe Title" .
```

**Scenario 2: Shard Rebalancing Conflicts**
```turtle
# During migration, same entry appears in multiple shards temporarily
# LWW-Register ensures consistent entry content across all shard copies
# Empty shards are tombstoned after migration completes
```

**Self-Healing Process:**
- Applications can trigger index validation by comparing index entries with source resources
- Framework provides utilities to regenerate index entries from authoritative data
- Inconsistencies are typically self-limiting due to LWW-Register's deterministic nature

## Configuration Version Conflict Handling

When a client detects that `idx:configVersion` was not properly incremented, the system automatically resolves conflicts:

### Auto-Resolution Algorithm

1. **Detect conflict:** `shard-mod-md5-2-0-v2_0_0` has tombstoned entries blocking new additions
2. **Auto-increment conflict:** Try `shard-mod-md5-2-0-v2_0_1`, then `v2_0_2`, `v2_0_3`, etc.
3. **Find unused version:** Stop at first version without conflicts (no shard or entry tombstones)
4. **Update configuration:** Set `idx:configVersion` to the working version (e.g., `"2_0_1"`)
5. **Continue sync:** Proceed with new shards using the conflict-free version

### Deterministic Resolution

- All clients follow identical algorithm, converging on same solution
- Multiple concurrent clients will discover same working version
- Manual developer override (e.g., `v3`) takes precedence over auto-generated versions

### Version Precedence Rules

- `v3_0_0` > `v2_999_999` (higher major version wins)  
- `v2_2_0` > `v2_1_0` (higher scale version wins)
- `v2_1_5` > `v2_1_3` (higher conflict resolution wins)
- Lexicographic comparison: `"2_1_0"` vs `"2_0_5"` → `"2_1_0"` wins

### Benefits

- **Self-scaling:** System automatically increases shard count as data grows
- **Self-healing:** No manual intervention required for configuration cycles or conflicts
- **Concurrent-safe:** Multiple clients reach same conclusion independently  
- **Zero-config:** Developers need no configuration (system defaults to `v1_0_0` and 1 shard), library makes defaults explicit
- **Performance optimized:** Proactive scaling prevents performance degradation
- **No data loss:** System continues functioning instead of stopping on conflicts

## When Sharding Decisions Are Made

- **During writes:** Calculate shard using current numberOfShards, migrate if found in wrong location
- **During reads:** Check all active shards in `idx:hasShard` to locate entries (read-only, no migration)
- **During discovery:** Search all active shards listed in `idx:hasShard` to locate entries
- **During config changes:** Validate new shard names against tombstone list before proceeding