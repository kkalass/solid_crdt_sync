# Performance Guide

This document provides detailed performance analysis and optimization guidance for PaCoRS implementations. For architectural overview, see [ARCHITECTURE.md](ARCHITECTURE.md).

## 1. Sync Performance Patterns

### 1.1. Performance Characteristics by Scenario

**Cold Start (No Local Cache):**
- Must discover Type Index, indices, and download all relevant index shards
- Download time scales with number of data types and shards per type
- Typical scenario: 1-10 data types × 1-16 shards each = 1-160 HTTP requests for indices
- No opportunity for change detection optimization

**Incremental Sync (Has Local Cache):**
- Compare cached shard Hybrid Logical Clock hashes with remote versions
- Download only changed shards (typically 0-20% on active datasets)
- Efficient change detection enables responsive sync experience

**Performance Patterns:**
- **Cold Start:** O(s) where s = number of index shards (must download all shards for selected indices)
- **Incremental Sync:** O(k) where k = number of changed shards (compare cached vs remote shard Hybrid Logical Clock hashes)
- **Change Detection:** O(1) per shard to detect changes (Hybrid Logical Clock hash comparison)
- **Bandwidth:** Index headers provide metadata without downloading full resources

## 2. Complete Sync Performance by Strategy

Performance estimates include both index synchronization and data synchronization phases. 

**Estimation Assumptions:**
- Network: Moderate broadband connection (~10Mbps)
- Resource size: ~50KB average per resource (recipes, documents, etc.)
- Pod server: Standard Community Solid Server performance
- Actual performance varies significantly based on network, server, and resource sizes

### 2.1. Small Collections (< 100 resources, ~5MB total data)

**FullSync (Index + All Data):**
- **Cold Start:** ~3-8 seconds (500ms index + 2-7s download all resources)
- **Incremental:** ~100ms-3s (100ms index check + 0-3s download changed resources)
- **Use Case:** Settings, small contact lists, preferences

**OnDemandSync (Index Only):**
- **Cold Start:** ~200-500ms (index only, data fetched on individual requests)
- **Incremental:** ~100-200ms (index sync only)
- **Individual Fetch:** ~50-200ms per resource when requested

### 2.2. Medium Collections (100-1000 resources, ~50MB total data)

**FullSync (Index + All Data):**
- **Cold Start:** ~30-120 seconds (1-3s index + 30-120s download all resources)
- **Incremental:** ~200ms-15s (500ms index + 0-15s changed resources)
- **Use Case:** Generally not recommended due to long sync times

**GroupedSync (Index + Active Groups):**
- **Cold Start:** Depends on subscribed group sizes, not total collection size
  - Small groups (10-50 resources): ~1-5 seconds (1-3s index + 1-2s download groups)
  - Medium groups (50-200 resources): ~3-10 seconds (1-3s index + 2-7s download groups)
- **Incremental:** ~500ms-3s (500ms index + 0-2s changed group resources)
- **Use Case:** Shopping lists for current month, recent activity logs

**OnDemandSync (Index Only):**
- **Cold Start:** ~1-3 seconds (index synchronization only)
- **Incremental:** ~200-500ms (index sync only)
- **Individual Fetch:** ~100-500ms per resource when requested

### 2.3. Large Collections (1000+ resources, ~500MB+ total data)

**FullSync:**
- **Not Recommended:** Could take 5-20+ minutes for complete data download
- **Mobile Impractical:** Exceeds background sync limits, large bandwidth usage

**GroupedSync (Selective Groups):**
- **Cold Start:** Performance depends on subscribed group sizes, not total collection size
  - Small groups (10-50 resources): ~3-8 seconds (3-10s index + 1-3s download groups)
  - Medium groups (50-200 resources): ~5-15 seconds (3-10s index + 2-7s download groups)
  - Large groups (200+ resources): ~10-30 seconds (3-10s index + 5-20s download groups)
- **Incremental:** ~500ms-5s (1-2s index + 0-3s changed group resources)
- **Use Case:** Current/recent time periods only

**OnDemandSync (Essential for Large Datasets):**
- **Cold Start:** ~3-10 seconds (index synchronization only)
- **Incremental:** ~500ms-2s (index sync only)
- **Individual Fetch:** ~200ms-1s per resource when requested
- **Browse Performance:** Near-instant (metadata from index headers)

## 3. Bandwidth Usage Analysis

### 3.1. Index Synchronization

- **Minimal Headers:** ~100-200 bytes per resource (IRI + Hybrid Logical Clock hash + 1-2 properties)
- **Compression:** HTTP/2 and gzip reduce overhead by ~60-80%
- **Incremental:** Only changed shards downloaded on subsequent syncs

### 3.2. Data Synchronization

- **On-Demand:** Download only requested resources
- **State-Based Merge:** Full resource download (no delta compression)
- **CRDT Overhead:** Hybrid Logical Clocks add ~50-100 bytes per resource

### 3.3. Sync Strategy Performance Impact

- **FullSync:** Linear scaling with total dataset size - becomes impractical > 1000 resources
- **GroupedSync:** Linear scaling with subscribed group sizes only (independent of total collection size)
- **OnDemandSync:** Constant-time sync regardless of total dataset size - essential for large collections

**Key Insight:** GroupedSync performance depends only on the size of groups you subscribe to, not the total number of groups or resources in the Pod.

## 4. Performance Bottlenecks

### 4.1. Network Latency

- **HTTP Round-Trips:** Each shard requires separate request
- **Mitigation:** HTTP/2 multiplexing, parallel shard fetching
- **Critical Path:** Index sync must complete before data sync

### 4.2. Merge Computation

- **Property-by-Property:** O(p) where p = number of properties
- **Hybrid Logical Clock Comparison:** O(c) where c = number of installations
- **Typically Fast:** Modern devices handle 100+ resources/second

### 4.3. Pod Server Limits

- **Rate Limiting:** Some servers limit concurrent requests
- **File Size:** Very large shards (>1MB) may cause server issues
- **Mitigation:** Automatic shard splitting at 1000 entries

## 5. Mobile and Offline Considerations

### 5.1. Background Sync Constraints

- **iOS:** 30-second background app refresh limit
- **Android:** Doze mode and battery optimization restrictions
- **Strategy:** Prioritize index sync, defer full data sync to foreground

### 5.2. Storage Efficiency

- **Local Cache:** Keep index data compact (~10% of full data size)
- **Selective Storage:** Cache only frequently accessed resources
- **Cleanup:** Automatic removal of stale cache entries

## 6. Optimization Strategies

### 6.1. Sharding Benefits

- **Parallel Fetching:** Multiple shards can be synchronized concurrently
- **Partial Failure Resilience:** Failed shards don't block others
- **Load Distribution:** Large indices split across multiple HTTP requests

### 6.2. Strategy Selection Guidelines

**Choose FullSync when:**
- Dataset is small (< 100 resources)
- All data is frequently accessed
- Offline operation is critical

**Choose GroupedSync when:**
- Data has natural time-based or logical groupings
- Users work with specific subsets (e.g., current month's data)
- Partial sync is acceptable

**Choose OnDemandSync when:**
- Dataset is large (> 1000 resources)
- Data access patterns are unpredictable
- Browse-then-load workflow is acceptable

## 7. Performance Monitoring

### 7.1. Key Metrics

- **Sync Duration:** Time from sync start to completion
- **Bandwidth Usage:** Bytes transferred per sync operation
- **Cache Hit Rate:** Percentage of index shards that haven't changed
- **Error Rate:** Failed operations per sync attempt

### 7.2. Performance Benchmarking

- **Cold Start Times:** Fresh installation sync performance
- **Incremental Sync Times:** Regular operation performance
- **Resource Access Times:** OnDemand fetch responsiveness
- **Memory Usage:** Peak memory during sync operations

## 8. Comparison with Alternative Approaches

### 8.1. vs. Full Resource Polling

- **Bandwidth:** 90%+ reduction through index-based change detection
- **Responsiveness:** Near-instant conflict-free merging vs. manual resolution

### 8.2. vs. Operation-Based CRDTs

- **Simplicity:** State-based merging works with any storage backend
- **Reliability:** No operation log synchronization required
- **Trade-off:** Higher bandwidth per change, but simpler implementation

### 8.3. vs. Centralized Databases

- **Offline Capability:** Full functionality without network connectivity
- **Scalability:** No single point of failure or bottleneck
- **Trade-off:** More complex conflict resolution, higher sync overhead

## 9. Performance Testing Recommendations

### 9.1. Test Scenarios

- **Synthetic Load:** Generate test datasets of varying sizes
- **Network Conditions:** Test on different connection speeds and latencies
- **Concurrent Users:** Multiple installations syncing simultaneously
- **Failure Conditions:** Network interruptions and server errors

### 9.2. Measurement Tools

- **Browser DevTools:** Network tab for HTTP request analysis
- **Performance API:** JavaScript timing measurements
- **Pod Server Logs:** Server-side performance metrics
- **Mobile Profiling:** Platform-specific performance tools

### 9.3. Optimization Priorities

1. **Index efficiency:** Minimize shard count and size
2. **Parallel operations:** Maximize concurrent request utilization
3. **Caching strategies:** Optimize local storage and retrieval
4. **Error handling:** Minimize retry overhead and cascading failures