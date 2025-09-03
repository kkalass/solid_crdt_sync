# Error Handling and Resilience Guide

This document provides comprehensive error handling strategies for solid-crdt-sync implementations. For architectural overview, see [ARCHITECTURE.md](ARCHITECTURE.md).

## 1. Network and Connectivity Failures

### Sync Failure Classification

Distinguish between systemic and resource-specific failures:

**Systemic Failures (abort entire sync):**
- Network connectivity issues (DNS, connection timeouts)
- Server errors (HTTP 500, 502, 503) indicating server overload/maintenance
- Authentication provider unavailable
- Pattern detection: >20% resource fetch failures suggests systemic issue

**Resource-Specific Failures (skip and continue):**
- Individual HTTP 404 (resource deleted/moved)
- Individual HTTP 403 (access control changed for specific resource)
- Individual parse errors (malformed RDF in single resource)

### Sync Recovery Strategies

- **Index Sync Interruption:** Always abort and retry from beginning - partial indices create inconsistent views
- **Systemic Failure Detection:** Stop current sync, schedule retry with exponential backoff (5min, 15min, 45min...)
- **Resource-Specific Failures:** Log failure, continue sync with remaining resources, retry failed resources on next sync cycle
- **Upload Failures:** Queue locally, retry with backoff, but preserve vector clock consistency

### Network Partitioning

During extended network unavailability:

- **Offline Operation:** Applications continue working with locally cached data and indices
- **Local-Only Updates:** Continue incrementing vector clocks for local changes
- **Sync Resume:** On reconnection, normal CRDT merge processes handle any conflicts from the partition period

## 2. Managed Resource Discovery Failures

### Comprehensive Setup Process

1. Check WebID Profile Document for solid:publicTypeIndex
2. If found, query Type Index for required managed resource registrations (sync:ManagedDocument with sync:managedResourceType schema:Recipe, idx:FullIndex, crdt:ClientInstallation, etc.)
3. Collect all missing/required configuration:
   - Missing Type Index entirely
   - Missing Type Registrations for managed data types (sync:ManagedDocument)
   - Missing Type Registrations for indices  
   - Missing Type Registrations for client installations
4. If any configuration is missing: Display single comprehensive "Pod Setup Dialog"
5. User chooses approach:
   1. "Automatic Setup" - Configure Pod with standard paths automatically
   2. "Custom Setup" - Review and modify proposed Profile/Type Index changes before applying
6. If user cancels: Run with hardcoded default paths, warn about reduced interoperability

### Setup Dialog Design Principles

- **Explicit Consent:** Never modify Pod configuration without user permission
- **Progressive Disclosure:** Automatic Setup shields users from complexity, Custom Setup provides full control
- **Clear Options:** Two main paths - trust the app or customize the details
- **Graceful Fallback:** Always offer alternative approaches if user declines configuration changes
- **Online-Only Operation:** Pod configuration modifications require network connectivity (not CRDT-compatible)

### Example Setup Dialog Flow

**Initial Setup Dialog:**
- **Title:** "Pod Setup Required"  
- **Message:** "This app needs to configure data storage in your Solid Pod to enable synchronization."
- **Options:**
  - ○ **Automatic Setup** - Use standard Solid paths (recommended)
  - ○ **Custom Setup** - Review and customize paths
- **Actions:** [Continue] [Cancel]

**Custom Setup Details (if chosen):**
- Type Index Location: `/settings/publicTypeIndex.ttl`
- Recipe Data: `/data/recipes/` [editable]
- Recipe Index: `/indices/recipes/index-full-a1b2c3d4/index` [editable]  
- Client Installations: `/installations/` [editable]
- **Actions:** [Apply Changes] [Cancel]

**Fallback Behavior (if user cancels entirely):**
App runs with fallback paths like `/solid-crdt-sync/recipes/` and warns about reduced interoperability with other Solid apps.

### Inaccessible Resources

When discovery finds IRIs that can't be fetched:
- **HTTP 404 (Not Found):** Remove stale entries from local cache, mark for re-discovery
- **HTTP 403 (Forbidden):** Log access control issue, continue with available data
- **HTTP 500 (Server Error):** Retry with exponential backoff, don't remove from cache

## 3. Merge Contract Failures

### Missing Merge Contracts

When `sync:isGovernedBy` references an inaccessible resource:

```
1. Attempt to fetch merge contract with retries
2. Check local cache for previously fetched contract
3. If neither available: Mark resource as non-syncable, work offline only
4. Display error to user about sync unavailability for this data type
5. Periodically retry contract fetching in background
```

### Corrupted Merge Contracts

When merge contract parsing fails:
- **Syntax Errors:** Mark resources as non-syncable, work offline, display error to user
- **Unknown CRDT Types:** 
  - If no local changes to property: Accept remote state ("trust remote")
  - If local changes exist: Skip property in merge, keep local value, continue syncing other properties
  - Log warning and recommend app update
- **Missing Predicate Mappings:** Use LWW-Register fallback based on vector clocks, log warning

### Version Conflicts

When different clients reference different contract versions:
- Treat `sync:isGovernedBy` as CRDT-managed property itself (see CRDT Specification for details)
- If contracts fundamentally contradict: Mark resources as non-syncable until resolved

## 4. Index Consistency Failures

### Shard Inconsistencies

When index shards contain conflicting information:

```
1. Detect inconsistency during index merge (conflicting vectorClockHash values)
2. Fetch all conflicting shards and compare vector clocks
3. Use CRDT merge logic on shard contents themselves
4. Write merged shard back to Pod
5. Log inconsistency for monitoring/debugging
```

### Missing Index Shards

When group index references non-existent shards:
- **Remove stale shard references** from group index
- **Create empty replacement shards** if write access available
- **Continue with available shards** to maintain partial functionality

### Index-Data Divergence

When index entries point to non-existent or modified data:
- **Validate index entries** against actual data resource vector clocks
- **Remove stale entries** during index sync
- **Rebuild index entries** for resources with updated clocks
- **Rate-limit rebuilding** to avoid performance impact

## 5. Authentication and Authorization

### Authentication Failures

- **Expired Tokens:** Attempt token refresh through authentication provider
- **Invalid Credentials:** Prompt user to re-authenticate
- **Provider Unavailable:** Skip sync operations, continue working with local data and incrementing vector clocks for offline changes

### Access Control Changes

When resource permissions change between syncs:
- **HTTP 403 on Previously Accessible Resource:** Keep in local cache, mark as sync-blocked, inform user of access issue
- **Partial Access Loss:** Continue with accessible resources, inform user of limited functionality  
- **Permission Escalation:** Retry previously failed operations, update local capabilities

## 6. Data Integrity Failures

### Vector Clock Anomalies

- **Clock Regression:** Detect and log impossible clock decreases, reject such updates
- **Unknown Installation IDs:** Preserve unknown entries as-is (no need to validate existence)
- **Massive Clock Skew:** Log warning about potential installation ID collision or corruption

### RDF Parse Errors

When resource content is malformed:
- **Syntax Errors:** Mark resource as non-syncable, work offline only, inform user
- **Schema Violations:** Use available valid properties, log warnings for invalid ones
- **Encoding Issues:** Attempt alternative parsers, character set detection

## 7. Performance Degradation Handling

### Large Resource Handling

- **Timeout Protection:** Abort operations exceeding configurable time limits
- **Memory Pressure:** Use streaming/partial processing for oversized resources
- **Selective Sync:** Allow applications to skip problematic large resources

### High Conflict Scenarios

When merge operations become expensive:
- **Conflict Rate Monitoring:** Track merge complexity and warn on excessive conflicts
- **Back-pressure Mechanisms:** Slow sync rate when merge queue grows large
- **User Notification:** Inform users about sync performance issues

## 8. Fallback and Recovery Strategies

### Graceful Degradation

1. **Full Functionality:** All discovery, sync, and merge operations working
2. **Limited Discovery:** Manual resource specification, reduced auto-discovery
3. **Read-Only Mode:** Can fetch and display data, cannot sync changes
4. **Offline Mode:** Work with local cache only, queue changes for later sync

### Recovery Procedures

- **Sync State Reset:** Clear local cache and re-sync from Pod (last resort)
- **Selective Recovery:** Rebuild specific indices or resource caches
- **Error Resolution UI:** Present merge contract failures or data corruption issues requiring user intervention (CRDT merges themselves never fail)

## 9. Sync Blocking Granularities

Understanding the different levels at which synchronization can be blocked helps implementers design appropriate user interfaces and recovery strategies.

### Type-Level Blocking (Entire Data Type Cannot Sync)

**Causes:**
- **Missing Merge Contracts:** No `sync:isGovernedBy` reference can be resolved
- **Corrupted Merge Contracts:** Syntax errors make contract unparseable  
- **Missing Type Registrations:** Cannot discover where data of this type is stored
- **Authentication Failures:** No access to any resources of this type

**User Impact:** All recipes, all shopping lists, etc. stop syncing
**UI Suggestion:** "Recipe sync unavailable - [Details] [Retry]"

### Resource-Level Blocking (Individual Resource Cannot Sync)

**Causes:**
- **RDF Parse Errors:** Resource content is malformed and unparseable
- **Access Control Loss:** HTTP 403 for previously accessible specific resource
- **Network Failures:** Specific resource consistently unreachable (while others work)
- **Vector Clock Corruption:** Clock regression or invalid clock data

**User Impact:** "Tomato Soup recipe" won't sync, but other recipes work fine
**UI Suggestion:** "Some recipes cannot sync - [Show Details] [Work Offline]"

### Property-Level Blocking (Specific Property Cannot Sync)

**Causes:**
- **Unknown CRDT Types:** Property uses algorithm not supported by this client
- **Schema Violations:** Property value doesn't match expected format
- **Conflicting Contracts:** Different clients reference incompatible merge rules for same property

**User Impact:** Recipe name syncs fine, but rating stays local-only
**UI Suggestion:** "Recipe synced (some features require app update)"

### Implementation Guidance

- **Cascade Up:** Property failures don't block resource sync, resource failures don't block type sync
- **User Feedback:** Match error granularity to user mental model (they care about "recipes" more than "properties")
- **Recovery Paths:** Provide different retry/fix options based on blocking level
- **Monitoring:** Track blocking patterns to identify systemic vs. isolated issues

## 10. Error Monitoring and Diagnostics

### Logging Strategies

- **Error Classification:** Tag errors by type, granularity, and recoverability
- **Performance Metrics:** Track sync times, failure rates, and resource sizes
- **User Impact Tracking:** Monitor how errors affect actual application functionality

### Diagnostic Information

- **Vector Clock States:** Include clock values in error reports for debugging
- **Network Conditions:** Log connection quality and server response patterns
- **Resource Metadata:** Include resource IRIs, sizes, and modification times

### Recovery Metrics

- **Success Rates:** Track percentage of resources/properties that sync successfully
- **Recovery Time:** Measure how long it takes to recover from different error types
- **User Intervention:** Track which errors require user action vs. automatic recovery