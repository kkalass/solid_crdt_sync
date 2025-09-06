# **Synchronization Algorithm Sketch**

This document outlines the high-level algorithm for the client-side synchronization library, aligned with the current 4-layer architecture.

## **Phase 1: Service Initialization**

This phase runs once when the service is started (e.g., on app launch).

1. **On Service Start:**  
   1. Begin listening to the injected AuthenticationService.  
   2. When the status becomes authenticated, begin a recurring schedule for **Discovery and Sync Attempts** (e.g., trigger one immediately, then periodically, and whenever the application comes online).

## **Phase 2: Discovery and Setup**

This unified process handles first-time setup and ongoing discovery for each sync attempt.

1. **Core Profile Discovery:**  
   1. Perform a conditional GET (with ETag) for the user's WebID Profile Document.  
   2. From the profile, discover and perform a conditional GET for the Public Type Index.  
   3. If any of these requests fail due to network issues, the sync attempt is aborted. The app remains functional in an offline state. The next scheduled sync will retry.

2. **Framework Configuration Discovery:**
   1. Query the Type Index for framework-specific types:
      - Data types registered by the application (e.g., `schema:Recipe`, `meal:ShoppingListEntry`)
      - Corresponding index types (e.g., `idx:FullIndex`, `idx:GroupIndexTemplate`)
      - Client installation containers (`crdt:ClientInstallation`)
   
3. **Missing Configuration Handling:**
   1. **If any required configuration is missing (Type Index, data type registrations, index registrations, client installations):**
      * Display comprehensive "Pod Setup Dialog" with user consent options
      * Allow "Automatic Setup" or "Custom Setup" with path review
      * If user cancels: Use hardcoded default paths, warn about reduced interoperability
      * The current sync attempt concludes here until setup is complete

   2. **If configuration is complete:** Proceed to the management phase

## **Phase 3: Index Management and Consistency Checks**

This phase performs maintenance operations and validates index consistency before synchronization.

1. **Installation Lifecycle Management:**
   1. **Self-activity update:** Update own `crdt:lastActiveAt` timestamp (limited to once per hour)
   2. **Lazy dormancy validation process:**
      * **Frequency:** Opportunistic validation during normal index operations
      * **Scope:** Only validate installations encountered in current sync operations
      * **Validation algorithm:**
        1. For each installation in `idx:readBy` lists of accessed indices:
           - Check local cache for recent validation (TTL: 24 hours)
           - If cache miss: Fetch installation document and check `crdt:lastActiveAt`
           - If inactive beyond threshold: Tombstone installation, remove from reader lists
        2. Skip global scans to avoid performance impact with large installation counts
      * **Batch optimization:** Group installation fetches to minimize HTTP requests
      * **Scalability:** Performance independent of total installation count
   3. **Collaborative cleanup:** Apply lifecycle-based reader list updates to all indices
   4. **Index lifecycle:** Check for indices with no active readers and tombstone them using framework deletion (`crdt:deletedAt`)

2. **Index Consistency Validation:**
   1. **Reader list verification:** Ensure all `idx:readBy` installations are still active
   2. **Populating shard progress:** Check status of any ongoing population processes
   3. **State validation:** Verify index `idx:populationState` matches actual shard availability
   4. **Garbage collection:** Process framework GC index for cleanup of old tombstoned shards

3. **Index Structure Conflicts:**
   1. **Immutable property conflicts:** Detect and resolve structural conflicts (abort if unresolvable)
   2. **Shard availability:** Validate all active shards in `idx:hasShard` are accessible
   3. **Version conflicts:** Check for concurrent index structure changes requiring merge

## **Phase 4: Index-Based Synchronization**

This process synchronizes indices based on the configured Sync Strategies.

1. **Strategy-Based Index Selection:**
   1. For each configured SyncStrategy:
      * **FullSync with `idx:FullIndex`:** Sync the single, monolithic index for the type
      * **GroupedSync with `idx:GroupIndexTemplate`:** Sync specific group indices based on active subscriptions
      * **OnDemandSync with `idx:FullIndex`:** Sync only the index, defer data fetching

2. **Index Discovery and Sync:**
   1. **For FullIndex or GroupIndex:**
      * Fetch the index document using conditional GET (ETag-based)
      * If 304 Not Modified, the index is unchanged - skip to next
      * If changed, merge using the index's own CRDT rules (from its `sync:isGovernedBy`)
   
   2. **For GroupIndexTemplate (discovery only):**
      * Fetch the template to understand group structure
      * Use template rules to determine which GroupIndex instances to sync
      * Apply the Index Discovery and Sync process to each relevant GroupIndex

3. **Shard Synchronization:**
   1. Read the `idx:hasShard` list from the (now updated) index
   2. For each shard, perform conditional GET
   3. For changed shards, merge using shard's CRDT logic
   4. Update local index cache with merged shard contents

4. **Application Notification:**
   1. Construct complete ResourceHeader list for the synchronized index
   2. Notify registered IndexChangeListeners via `onIndexUpdate` callback
   3. Pass source ID (index path or group path) and headers list

## **Phase 5: Data Synchronization**

This phase handles actual data resource synchronization based on the sync strategy.

1. **Strategy-Based Data Fetching:**
   1. **FullSync/GroupedSync:** Immediately fetch all resources listed in synchronized indices
   2. **OnDemandSync:** Wait for explicit `fetchFromRemote()` calls from application

2. **Resource Merge Process:**
   1. **For each resource to be fetched:**
      * Perform conditional GET on the data resource
      * If unchanged (304), skip to next resource
      * If changed or new, proceed with merge

   2. **State-Based CRDT Merge:**
      * Fetch the resource's merge contract (`sync:isGovernedBy`)
      * Compare Hybrid Logical Clocks to determine merge necessity
      * Perform property-by-property merge using contract rules
      * Update resource's Hybrid Logical Clock and metadata

3. **Index Maintenance:**
   1. **After successful resource merge:**
      * Determine which indices this resource belongs to (via `idx:belongsToIndexShard`)
      * For each affected index shard:
        - Fetch current shard
        - Update the resource's entry with new Hybrid Logical Clock hash
        - Update any indexed properties (schema:name, etc.)
        - Upload updated shard

4. **Application Notification:**
   1. Notify registered DataChangeListeners via `onUpdate` callback
   2. Pass the merged object for local storage/display

## **Phase 6: Write Path (On store(object))**

This process is triggered when the application calls `store()` on an object.

1. **Strategy-Based Location Determination:**
   1. Look up the SyncStrategy for the object's type
   2. **For FullSync:** Determine shard based on current sharding algorithm configuration
   3. **For GroupedSync:** Apply discovered GroupingRule to determine group(s), then calculate shard within group
   4. **For OnDemandSync:** Same as FullSync (single index, determine shard)

2. **Resource Merge and Update:**
   1. Fetch current version of data resource from Solid Pod
   2. Perform state-based CRDT merge with local changes
   3. Increment local client's Hybrid Logical Clock
   4. Upload merged resource to Solid Pod

3. **Index Updates:**
   1. For each index the resource belongs to:
      * Fetch affected shard(s) using current configuration (handle legacy shards if present)
      * Update entries with new Hybrid Logical Clock hash and indexed properties
      * Check if shard exceeds autoScaleThreshold during update
      * If scaling needed: auto-increment configVersion and begin lazy migration to new shard count
      * Upload updated shard(s)

4. **Cross-Strategy Consistency:**
   1. If resource belongs to multiple indices (different applications/strategies):
      * Update all relevant index shards
      * Ensure Hybrid Logical Clock consistency across all references

## **Phase 7: Automatic Scaling Management**

This process handles automatic shard scaling when capacity thresholds are exceeded.

1. **Scaling Detection:**
   1. During index updates, monitor entry counts per shard
   2. When any shard exceeds `idx:autoScaleThreshold` (default: 1000 entries)
   3. Trigger automatic scaling process

2. **Configuration Update:**
   1. Calculate new shard count (typically double: 1→2→4→8→16)
   2. Auto-increment configVersion scale component: `v1_0_0` → `v1_1_0`
   3. Update index configuration with new `numberOfShards` and `configVersion`
   4. Add new shard names to `idx:hasShard` list using format `shard-mod-xxhash64-{count}-{num}-v{major}_{scale}_{conflict}`

3. **Lazy Migration Initialization:**
   1. Begin using new shard count for all new entries
   2. Existing entries remain in legacy shards until opportunistically migrated
   3. Read operations check all active shards listed in `idx:hasShard`
   4. Write operations migrate entries if found in non-current shards

4. **Conflict Resolution:**
   1. If configVersion conflicts detected (2P-Set rejects shard name or entry)
   2. Auto-increment conflict component: `v1_1_0` → `v1_1_1`
   3. Retry with new conflict-free version
   4. All clients converge on same resolution deterministically

## **Framework-Required Automatic Synchronization**

The library automatically synchronizes specific document types that are essential for framework operation, regardless of application-configured sync strategies.

**Mandatory Sync Documents:**

1. **Installation Documents (`crdt:ClientInstallation`):**
   - **Frequency:** Every sync cycle (background maintenance)
   - **Scope:** All installations referenced in any `idx:readBy` list
   - **Purpose:** Dormancy detection, lifecycle management, collaborative coordination
   - **Strategy:** Always FullSync (small documents, critical for system health)

2. **Index Documents (`idx:Index` subclasses):**
   - **Frequency:** Every sync cycle before data synchronization
   - **Scope:** All indices required by configured application sync strategies
   - **Purpose:** Change detection, shard discovery, population status tracking
   - **Strategy:** Index-specific (always download full index documents, conditionally sync shards)

3. **Framework Garbage Collection Index:**
   - **Frequency:** Weekly during management phase
   - **Scope:** Framework-level GC index for tombstoned shard cleanup
   - **Purpose:** Automated cleanup of temporary populating shards
   - **Strategy:** FullSync (single system-wide index)

**Application Document Sync:**
- Data resources (e.g., `schema:Recipe`) sync according to application-configured strategies
- Index shards sync based on change detection and strategy requirements
- Merge contracts sync on-demand when referenced by data resources

**Performance Considerations:**
- Installation document sync scaled using lazy validation approach
- Index documents are typically small and critical for system operation
- GC index provides system-wide cleanup without per-application overhead

## **Error Handling Integration**

All phases integrate the comprehensive error handling strategies defined in the Architecture document:

* **Network failures:** Distinguish systemic vs. resource-specific failures
* **Discovery failures:** Graceful setup dialog flow with fallback options  
* **Merge contract failures:** Offline-only mode for affected resources
* **Index inconsistencies:** CRDT-based shard repair and validation
* **Performance degradation:** Timeout protection and selective sync

## **Key Implementation Notes**

1. **Type Index as Single Source of Truth:** Always use Type Index for discovery, never hardcoded paths
2. **Conditional Requests:** Leverage HTTP ETags for bandwidth efficiency
3. **Document-Level Hybrid Logical Clocks:** Maintain causality across all index and data updates using document-level Hybrid Logical Clocks
4. **Strategy Flexibility:** Support mixed strategies (FullSync recipes + GroupedSync shopping entries)
5. **Zero-Configuration Scaling:** System defaults to single shard with automatic scaling (1→2→4→8→16) based on entry thresholds
6. **Self-Healing Conflicts:** Automatic configVersion conflict resolution using deterministic suffix increments
7. **Graceful Degradation:** Continue operation with partial functionality when possible