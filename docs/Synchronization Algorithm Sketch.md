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

   2. **If configuration is complete:** Proceed to the sync process

## **Phase 3: Index-Based Synchronization**

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

## **Phase 4: Data Synchronization**

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
      * Compare vector clocks to determine merge necessity
      * Perform property-by-property merge using contract rules
      * Update resource's vector clock and metadata

3. **Index Maintenance:**
   1. **After successful resource merge:**
      * Determine which indices this resource belongs to (via `idx:belongsToIndexShard`)
      * For each affected index shard:
        - Fetch current shard
        - Update the resource's entry with new vector clock hash
        - Update any indexed properties (schema:name, etc.)
        - Upload updated shard

4. **Application Notification:**
   1. Notify registered DataChangeListeners via `onUpdate` callback
   2. Pass the merged object for local storage/display

## **Phase 5: Write Path (On store(object))**

This process is triggered when the application calls `store()` on an object.

1. **Strategy-Based Location Determination:**
   1. Look up the SyncStrategy for the object's type
   2. **For FullSync:** Determine shard based on sharding algorithm
   3. **For GroupedSync:** Use grouper function to determine group(s), then shard within group
   4. **For OnDemandSync:** Same as FullSync (single index, determine shard)

2. **Resource Merge and Update:**
   1. Fetch current version of data resource from Solid Pod
   2. Perform state-based CRDT merge with local changes
   3. Increment local client's vector clock
   4. Upload merged resource to Solid Pod

3. **Index Updates:**
   1. For each index the resource belongs to:
      * Fetch affected shard(s)
      * Update entries with new vector clock hash and indexed properties
      * Upload updated shard(s)

4. **Cross-Strategy Consistency:**
   1. If resource belongs to multiple indices (different applications/strategies):
      * Update all relevant index shards
      * Ensure vector clock consistency across all references

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
3. **Vector Clock Consistency:** Maintain causality across all index and data updates
4. **Strategy Flexibility:** Support mixed strategies (FullSync recipes + GroupedSync shopping entries)
5. **Graceful Degradation:** Continue operation with partial functionality when possible