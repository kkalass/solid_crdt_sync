# **Synchronization Algorithm Sketch**

This document outlines the high-level algorithm for the client-side synchronization library.

## **Phase 1: Service Initialization**

This phase runs once when the service is started (e.g., on app launch).

1. **On Service Start:**  
   1. Begin listening to the injected AuthenticationService.  
   2. When the status becomes authenticated, begin a recurring schedule for **Sync Attempts** (e.g., trigger one immediately, then periodically, and whenever the application comes online).

## **Phase 2: The Sync Attempt**

This is the unified loop that runs for every scheduled sync. It naturally handles the first-time run.

1. **Fetch Core Profiles & Check Configuration:**  
   1. Perform a conditional GET (with ETag) for the user's main Profile Document (WebID).  
   2. From the profile, discover and perform a conditional GET for the Public Type Index.  
   3. If any of these requests fail due to network issues, the sync attempt is aborted. The app remains functional in an offline state. The next scheduled sync will retry.  
   4. Attempt to fetch the library's private configuration file from the user's Pod (e.g., /settings/my-app-registry).  
   5. **If the configuration file is not configured in the Profile Document, not found (404) or is found but is incomplete (e.g., missing required settings for the current app version):**  
      * This indicates a first-time setup or a configuration update is needed.  
      * Trigger a "Setup Required" flow in the application's UI, using appropriate phrasing ("Welcome\!" for a new setup, "Configuration update needed" for an incomplete one).  
      * The current sync attempt concludes here. The flow will resume after the user completes the setup.  
   6. **If the configuration file is found and is complete:** Proceed to the sync loop.  
2. **Run the Sync Loop:**  
   1. For each SyncStrategy configured by the developer (FullSync, OnDemandSync):  
      * Trigger the **Index Sync Process** for the single, global index associated with that type (e.g., /indices/recipes/index).  
   2. FIXME: Is the partition handling here consistent?  
   3. FIXME: continue checking and fixing all remaining points  
   4. For each active subscription (e.g., from subscribeToPartition(...)):  
      * Trigger the **Index Sync Process** for the corresponding partition's index root (e.g., /indices/shopping-entries/partitions/2025-08).

## **Phase 3: The Index Sync Process (for a given index root)**

This is the core process for synchronizing a single index (whether it's a global one or a partition).

1. **Fetch Root Index:**  
   1. Perform a conditional GET on the root index resource (e.g., /indices/recipes/index).  
   2. If 304 Not Modified, the entire index is unchanged. The process for this index is complete.  
   3. If new data is received, merge it with the local cache using the appropriate CRDT logic (governed by its own rules file).  
2. **Fetch Shards:**  
   1. Read the list of shards from the (now updated) local copy of the root index.  
   2. For each shard in the list, perform a conditional GET.  
   3. For any shard that has changed, merge it with the local cache using its CRDT logic.  
3. **Notify the Application:**  
   1. After all shards for the index have been processed, construct the complete list of ResourceHeaders for that index.  
   2. Notify all registered IndexChangeListeners via the onIndexUpdate callback, passing the source ID (e.g., the partition path) and the list of headers.

## **Phase 4: The Write Path (On store(object))**

This process is triggered when the application developer calls store() on an object.

1. **Determine Location:**  
   1. Look up the SyncStrategy for the object's type.  
   2. Use the strategy's configuration (e.g., the partitioner and sharder functions) to determine the exact data resource IRI, partition IRI(s), and shard IRI(s) that will be affected.  
2. **Perform Merge:**  
   1. Fetch the current version of the data resource from the Solid Pod.  
   2. Perform the state-based CRDT merge between the local object and the remote data, according to the public rules file (sync:isGovernedBy).  
3. **Update Indices:**  
   1. For each index the resource belongs to (read from the sync:belongsToIndex links after the merge):  
      * Fetch the correct shard file for that index.  
      * Read the index's rules file to determine which properties to "pull" into the index.  
      * Update the shard with the new vector clock and header data for the object.  
      * Upload the new version of the shard file.  
4. **Update Data Resource:**  
   1. Upload the new, merged version of the data resource file.  
5. **Notify the Application:**  
   1. Notify all registered DataChangeListeners via the onUpdate callback, passing the newly merged object.