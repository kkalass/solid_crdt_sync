# Architecture Decision Records

This directory contains Architecture Decision Records (ADRs) for the solid_crdt_sync package.

## Current Status Overview

### 🟡 Proposed (Need Decision)
- **[ADR-0001](0001-iri-strategy-extension.md)**: IRI Strategy Extension for Local-First Architecture
  - **Priority**: High (blocks model design)
  - **Context**: How to handle dynamic IRI generation in local-first sync

### 🟢 Accepted
- **[ADR-0000](0000-use-architecture-decision-records.md)**: Use Architecture Decision Records
- **[ADR-0002](0002-dart-type-vs-rdf-type-mapping.md)**: Dart Type vs RDF Type Mapping
- **[ADR-0003](0003-sync-as-addon-architecture.md)**: Sync as Add-on Architecture

### 🔴 Rejected
(None yet)

## Quick Links
- [ADR Template](template.md)
- [All ADRs]()

## Process
1. **PROPOSED**: Issue identified, needs research/decision
2. **RESEARCH**: Actively investigating options
3. **ACCEPTED**: Decision made and being implemented
4. **REJECTED**: Decision explicitly rejected with rationale
5. **SUPERSEDED**: Replaced by later ADR

## Critical Path
The IRI Strategy decision (ADR-0001) is currently blocking progress on the core model design and should be prioritized.
