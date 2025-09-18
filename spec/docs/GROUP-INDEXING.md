# Group Indexing Specification

**Version:** 0.10.0-draft
**Last Updated:** September 2025
**Status:** Draft Specification

## Overview

The Solid CRDT Sync framework uses group indices to organize resources into hierarchical structures for efficient querying and synchronization. This document specifies the complete group indexing system, including property transformations, group key generation, hierarchical organization, and filesystem mapping.

## Motivation

Group indices enable scalable data organization by:

1. **Transforming property values** (dates, categories, identifiers) into normalized group keys
2. **Creating hierarchical structures** that map to filesystem directories
3. **Ensuring cross-platform compatibility** through standardized formats
4. **Supporting efficient partial sync** by enabling selective group loading

Regular expressions provide a flexible, declarative way to extract and reformat property values while maintaining RDF's language-agnostic nature.

**Cross-Platform Compatibility:** Rather than choosing between incompatible regex standards (POSIX ERE vs ECMAScript), we define a compatible subset that produces identical results across all platforms, ensuring consistent group key generation in distributed sync scenarios.

## Compatible Regex Subset

### Supported Pattern Elements

**Character Classes:**
- `[a-z]`, `[A-Z]`, `[0-9]` - standard ranges
- `[abc]`, `[^abc]` - literal sets and negation
- `[a-zA-Z]`, `[0-9a-fA-F]` - combined ranges

**Metacharacters:**
- `.` - any character (except newline)
- `^` - start of string anchor
- `$` - end of string anchor

**Quantifiers:**
- `*` - zero or more
- `+` - one or more
- `?` - zero or one
- `{n}` - exactly n occurrences
- `{n,m}` - n to m occurrences
- `{n,}` - n or more occurrences

**Grouping:**
- `(...)` - capture groups for backreferences

**Escaping:**
- `\` followed by any special character makes it literal
- Special characters: `. ^ $ [ ] ( ) { } * + ? \`

### Excluded Features

**Alternation (`|`):**
- Not supported within patterns due to platform-specific matching behavior
- Use multiple transform rules instead (see Transform Lists below)

**Named Character Classes:**
- No `[[:alpha:]]`, `[[:digit:]]`, etc. due to inconsistent platform support
- Use explicit ranges like `[a-zA-Z]`, `[0-9]` instead

### Replacement Syntax

The replacement syntax follows common conventions supported by most programming languages:

**Group References:**
- `${1}`, `${2}`, ..., `${n}` - backreferences to capture groups (braced syntax required)
- `${0}` - entire matched string

**Literal Text:**
- Any characters except `$` and `{}`
- Use `$$` for a literal `$` character
- Empty braces `${}` are invalid

**Disambiguation:**
- `${1}1` - group 1 followed by literal "1"
- `${11}` - group 11
- Maximum cross-platform compatibility through consistent braced syntax

### Cross-Platform Benefits

**Deterministic Behavior:**
- Identical results across all regex engines
- No platform-specific matching semantics
- Predictable group key generation in distributed systems

**Universal Support:**
- Works with JavaScript/ECMAScript engines
- Compatible with Java, .NET, Python, Go regex libraries
- No special flags or compatibility modes required

## Transform Configuration

Transforms are specified in RDF using ordered lists to ensure deterministic processing:

### Single Transform

```turtle
idx:transform (
  [
    a idx:RegexTransform;
    idx:pattern "^([0-9]{4})-([0-9]{2})-([0-9]{2})$";
    idx:replacement "${1}-${2}"
  ]
) .
```

### Multiple Transforms (for handling different input formats)

```turtle
idx:transform (
  [
    a idx:RegexTransform;
    idx:pattern "^([0-9]{4})-([0-9]{2})-([0-9]{2})$";
    idx:replacement "${1}-${2}"
  ]
  [
    a idx:RegexTransform;
    idx:pattern "^([0-9]{4})/([0-9]{2})/([0-9]{2})$";
    idx:replacement "${1}-${2}"
  ]
) .
```

### Processing Semantics

**Transform Order:** Transforms are applied in list order (first to last)

**Matching Strategy:** First matching transform wins
1. Try each transform pattern in order
2. Apply the first pattern that matches the input value
3. If no patterns match, use the original value unchanged

**CRDT Strategy:** Transform lists are immutable (part of grouping definition identity)

## Group Key Structure

### Hierarchical Format

Group keys support hierarchical organization using forward slashes (`/`) as level separators. This enables filesystem-based storage where each hierarchy level creates a directory structure.

**Hierarchy Levels:** Separated by `/` (forward slash)
```
level1/level2/level3
```

**Multiple Properties at Same Level:** Separated by `-` (hyphen)
```
property1-property2-property3
```

**Combined Example:**
```
work/2024-08/high-priority
```

This creates a filesystem structure:
```
work/
  2024-08/
    high-priority/
```

### Practical Examples

**Single property per level:**
- Group key: `personal/2024-01`
- Filesystem: `personal/2024-01/`

**Multiple properties at same level:**
- Group key: `work-urgent/2024-08/project-alpha`
- Filesystem: `work-urgent/2024-08/project-alpha/`

**Complex hierarchy:**
- Group key: `documents-archive/2023/Q4-reports/financial`
- Filesystem: `documents-archive/2023/Q4-reports/financial/`

### Format Rules

1. **Level separators** are always `/` to enable filesystem directory creation
2. **Same-level separators** are always `-` per ARCHITECTURE.md section 5.3.3 GroupingRule specification
3. **Property values** are transformed first, then combined according to hierarchy
4. **Missing properties** with `missingValue` are included in the normal combination logic
5. **Same-level ordering** follows lexicographic IRI ordering for deterministic results

### Properties

- **`idx:pattern`** (required): Compatible regex pattern string (no alternation)
- **`idx:replacement`** (required): Replacement template with `${n}` backreferences

## Data Type Handling

### Core Principle

**Regex transforms operate on the string representation of RDF literal values, ignoring datatypes and language tags.** 
For IRI values, they operate on the IRI string.

### Processing Rules

**RDF Literals:** Extract string content and apply regex transforms
```turtle
"2024-08-15"^^xsd:date → "2024-08-15" → transform applied
"42"^^xsd:integer → "42" → transform applied
"projet-alpha"@fr → "projet-alpha" → transform applied
```

**Blank Nodes:** Not supported
```turtle
_:item123 → implementations should throw an error
```

**IRI:** Use String representation of the iri
```turtle
<http://example.org/item/123> → "http://example.org/item/123" -> transform applied
```

### Error Handling

**No Transform Specified:** Use original RDF value as group key

**No Pattern Matches:** Use original RDF value as group key

**Invalid Pattern Syntax:** Implementation choice - log error and use original value, or reject configuration

### Grouping Behavior

Values with identical string representations group together regardless of datatype:
```turtle
"42"^^xsd:integer → group key "42"
"42"^^xsd:string → group key "42" (same group)
"42"@en → group key "42" (same group)
```

## Examples

### Date Transformations

**Monthly grouping:**
```turtle
idx:transform (
  [
    a idx:RegexTransform;
    idx:pattern "^([0-9]{4})-([0-9]{2})-([0-9]{2})$";
    idx:replacement "${1}-${2}"
  ]
) .
# "2024-08-15" → "2024-08"
```

**Yearly grouping:**
```turtle
idx:transform (
  [
    a idx:RegexTransform;
    idx:pattern "^([0-9]{4})-[0-9]{2}-[0-9]{2}$";
    idx:replacement "${1}"
  ]
) .
# "2024-08-15" → "2024"
```

**Handle multiple date formats:**
```turtle
idx:transform (
  [
    a idx:RegexTransform;
    idx:pattern "^([0-9]{4})-([0-9]{2})-([0-9]{2})$";
    idx:replacement "${1}-${2}"
  ]
  [
    a idx:RegexTransform;
    idx:pattern "^([0-9]{4})/([0-9]{2})/([0-9]{2})$";
    idx:replacement "${1}-${2}"
  ]
) .
# "2024-08-15" → "2024-08" (first transform matches)
# "2024/08/15" → "2024-08" (second transform matches)
```

### String Normalization

**Category extraction:**
```turtle
idx:transform (
  [
    a idx:RegexTransform;
    idx:pattern "^([a-zA-Z]+)[-_].*$";
    idx:replacement "${1}"
  ]
) .
# "work-project-alpha" → "work"
# "personal_notes" → "personal"
```

**Identifier reformatting:**
```turtle
idx:transform (
  [
    a idx:RegexTransform;
    idx:pattern "^([A-Z]{2})([0-9]+)$";
    idx:replacement "${1}-${2}"
  ]
) .
# "US123456" → "US-123456"
# "CA789012" → "CA-789012"
```

**Complex multi-format handling:**
```turtle
idx:transform (
  [
    a idx:RegexTransform;
    idx:pattern "^project[-_]([a-zA-Z0-9]+)$";
    idx:replacement "${1}"
  ]
  [
    a idx:RegexTransform;
    idx:pattern "^proj[-_]([a-zA-Z0-9]+)$";
    idx:replacement "${1}"
  ]
  [
    a idx:RegexTransform;
    idx:pattern "^([a-zA-Z0-9]+)[-_]project$";
    idx:replacement "${1}"
  ]
  [
    a idx:RegexTransform;
    idx:pattern "^([a-zA-Z0-9]+)[-_]proj$";
    idx:replacement "${1}"
  ]
) .
# "project-alpha" → "alpha" (first transform matches)
# "proj_beta" → "beta" (second transform matches)
# "gamma-project" → "gamma" (third transform matches)
# "delta_proj" → "delta" (fourth transform matches)
```

## Implementation Guidelines

### Compatible Subset Support

Implementations must support the compatible regex subset defined above. This ensures:

- Identical matching behavior across all platforms
- Deterministic group key generation
- Reliable sync in distributed environments

### Transform List Processing

**Order:** Process transforms in list order (first to last)

**First Match Wins:** Apply the first matching pattern, skip remaining patterns

**Fallback:** If no patterns match, use original value unchanged

### Language-Specific Implementation

**JavaScript/TypeScript:** Use native `RegExp` - compatible subset works identically

**Dart/Flutter:** Use `RegExp` class - compatible subset works identically

**Java:** Use `java.util.regex.Pattern` - compatible subset works identically

**.NET:** Use `System.Text.RegularExpressions.Regex` - compatible subset works identically

**Python:** Use `re` module - compatible subset works identically

**Go:** Use `regexp` package - compatible subset works identically

### Validation

**Pattern Validation:** Check patterns against compatible subset before processing

**Forbidden Features:** Reject patterns containing `|` alternation or named character classes

**Error Handling:** Provide clear error messages for unsupported syntax

### Performance

**Simple Patterns:** Optimize basic patterns (single capture groups, simple character classes) for high-throughput processing

**Transform Lists:** Consider caching compiled patterns for repeated use

**Early Exit:** Stop processing transform list on first match

## Filesystem Safety

Group keys serve as filesystem path components and must be safe across all platforms. The framework automatically ensures filesystem safety for both individual group keys and hierarchical paths.

### Safety Requirements

**Cross-Platform Compatibility:** Group keys must work on Windows, Linux, macOS, and web filesystems without conflicts or errors.

**Path Component Safety:** Each group key becomes a directory or file name and must avoid:
- Filesystem-reserved characters: `< > : " / \ | ? * \x00-\x1F`
- Platform-reserved names: `CON`, `PRN`, `AUX`, `NUL`, `COM1-9`, `LPT1-9` (Windows)
- Directory navigation: `.`, `..`, empty strings
- Hidden file prefixes: Names starting with `.`

### Automatic Safety Enforcement

The framework applies filesystem safety automatically during group key generation:

#### Safe Key Preservation
Keys are preserved unchanged when they meet all criteria:
- **Character whitelist:** Only `[a-zA-Z0-9._-]` characters
- **Length limit:** 50 characters or fewer
- **Name safety:** Not `.`, `..`, or hidden (starting with `.`)

#### Hash-Based Fallback
Keys that fail safety checks are automatically converted using MD5:
- **Format:** `{originalLength}_{32-char-hex-hash}`
- **Hash algorithm:** MD5 (consistent with framework's sharding and clock hashing)
- **Deterministic:** Identical input always produces identical hash
- **Collision resistant:** 128-bit hash provides excellent collision resistance for grouping use cases

### Implementation Examples

**Safe keys (preserved):**
```
"work" → "work"
"2024-08" → "2024-08"
"project_alpha" → "project_alpha"
"v1.2.3" → "v1.2.3"
```

**Unsafe keys (hashed):**
```
"contains/slash" → "14_5d41402abc4b2a76b9719d911017c592"
"very-long-category-name-exceeding-fifty-characters" → "52_c4ca4238a0b923820dcc509a6f75849b"
"http://example.org/resource" → "26_098f6bcd4621d373cade4e832627b4f6"
"unicode-café-résumé" → "18_9bb58f26192e4ba00f01e2e7b136bbd8"
```

**Hierarchical paths:**
```
Safe: work/2024-08/high-priority
Mixed: work/14_5d41402abc4b2a76b9719d911017c592/high-priority
Unsafe: 4_abc123def456/26_def456789abc/13_789abcdef012
```

### Benefits

**Universal Compatibility:** Generated group keys work identically across all platforms and filesystems.

**Debuggability:** Character count prefix helps identify original content length and spot potential issues.

**Performance:** MD5 provides fast hashing with excellent distribution for collision avoidance.

**Determinism:** Identical group keys always produce identical filesystem-safe representations across all systems.

