# Trial Matrix Script Comparison

## Overview
This document compares `TrialMatrixSeq3way.m` (original) and `TrialMatrixSeq3way_ACW.m` (alternative, ACW rotation approach).

Both scripts create trial matrices for a sequential 3-way design with three conditions: **Baseline**, **RS** (Redundant Singletons), and **GS** (Grouped+Singleton).

---

## Key Differences

### 1. **Function Name**
- **Original**: `TrialMatrixSeq3way`
- **Alternative**: `TrialMatrixSeq3way_ACW` (ACW = Anti-Clockwise)

### 2. **Trial Generation Strategy**

#### Original (`TrialMatrixSeq3way.m`)
- **Direct row creation**: Loops through set sizes and directly creates rows based on repetition counts
- Creates rows individually: `rows(end+1,:) = {N, Rval, 'R', 'RS'};`
- **Trial counts per condition**:
  - Baseline: `floor(MainReps/2)` trials
  - RS: `MainReps` trials (half R-cue, half NR-cue)
  - GS: `MainReps` trials (half R-cue, half NR-cue)

#### Alternative (`TrialMatrixSeq3way_ACW`)
- **Base table + inflation**: Creates a base table with one row per condition combination, then uses `repelem()` to inflate
- **Base structure**: For each N, creates 5 base rows:
  1. Baseline (R=0, Cue='NR')
  2. RS (R>0, Cue='R')
  3. RS (R>0, Cue='NR')
  4. GS (R>0, Cue='R')
  5. GS (R>0, Cue='NR')
- Then replicates each base row `MainReps` times (or `PracticeReps` for practice)

### 3. **Spatial Position Assignment**

#### Original
- **Fixed 6 positions** starting at 12 o'clock (90°)
- Positions: `90, 150, 210, 270, 330, 30` degrees
- Selects first N positions for each trial
- **No rotation** - positions are always the same

#### Alternative
- **N evenly spaced positions** based on set size
- Base positions: `90 + (0:N-1)*(360/N)` degrees
- **Random rotation per trial**: `RingStart = randi(N)` rotates the ring
- Positions rotated: `circshift(baseLocs, [0, s0-1])`
- Adds `RingStart` column to track rotation

### 4. **Sequence Order Generation**

#### Original
- **Fixed spatial order**: Items presented in index order (1, 2, 3, ... N)
- For RS: Redundant items appear as **adjacent singletons** in the sequence
- For GS: Redundant items appear as **one grouped segment** (can wrap spatially)

#### Alternative
- **ACW (Anti-Clockwise) ring order**: Items presented in ACW order around the circle
- Ring order: `circshift(1:N, [0, s0-1])` - rotated by `RingStart`
- For RS: Redundant items appear as **adjacent singletons** in the ACW timeline
- For GS: Redundant items appear as **one grouped segment** (can wrap in timeline)

### 5. **RS Condition (Redundant Singletons)**

#### Original
- **Spatial adjacency**: Contiguous block WITHOUT wrap
- Start position: `randi(N-R)` → positions 1..(N-R)
- Example (N=4, R=2): Can be positions [1,2] or [2,3], but NOT [3,4,1]

#### Alternative
- **Timeline adjacency**: Contiguous block in ACW timeline WITHOUT wrap
- Start position: `randi(N-R+1)` → timeline steps 1..(N-R+1)
- Redundant items appear as adjacent singletons in the presentation sequence
- Example: If ring order is [3,4,1,2] and block starts at step 2, redundant items are [4,1] (adjacent in timeline)

### 6. **GS Condition (Grouped+Singleton)**

#### Original
- **Spatial grouping**: Contiguous block WITH wrap allowed
- Start position: `randi(N)` → can start anywhere
- Group can wrap: e.g., positions [5,6,1] for N=6
- **Group placement**: Randomly placed among (N-R+1) segments
- Sequence: `(N-R)` singleton steps + 1 group step

#### Alternative
- **Timeline grouping**: Multi-item group WITH wrap allowed in timeline
- Start position: `randi(N)` → can start anywhere in timeline
- Group can wrap in timeline: e.g., if ring is [5,6,1,2,3,4] and group starts at step 5, it wraps to [5,6,1]
- **Group placement**: Appears as one segment in the sequence
- Sequence: `(N-R)` singleton steps + 1 group step

### 7. **Sequence Tags**

#### Original
- Uses: `"R"` (redundant singleton), `"U"` (unique), `"RG"` (redundant group)
- Example: `"RRUU"`, `"URRU"`, `"RGUUU"`, `"UURGU"`

#### Alternative
- Uses: `"R"` (redundant singleton), `"U"` (unique), `"G"` (group)
- Example: `"RRUU"`, `"URRU"`, `"UUUG"`, `"UGUU"`

### 8. **Additional Columns**

#### Original
- `RedundantPositions`: Cell array of redundant position indices
- `UniquePositions`: Cell array of unique position indices
- `NoiseLevel`: Defaults to `'low'` (can be 'low' or 'high')
- `Grouping`: 'Grouped' or 'Separate'
- `SequenceTag`: String like "RRUU", "RGUUU"

#### Alternative
- `DupPos`: Cell array of redundant position indices (spatial positions)
- `RingStart`: Scalar indicating rotation offset (1..N)
- `Grouping`: 'Grouped' or 'Separate'
- `SequenceTag`: String like "RRUU", "UGUU"
- **No `NoiseLevel` column**

### 9. **Color Assignment**

Both scripts use similar logic:
- Redundant items: Same color (random hue)
- Unique items: Different colors with minimum spacing (30°)
- Colors assigned to spatial positions (not timeline positions)

---

## Conditions Created

Both scripts create the same **3 conditions × 2 cue types × 2 set sizes** structure:

### For each Set Size (N=4 or N=6):

1. **Baseline**
   - RedundantN = 0
   - CueType = 'NR' (no redundant cue possible)
   - All items are unique
   - Sequence: N singleton steps (all "U")
   - Grouping: 'Separate'

2. **RS (Redundant Singletons)**
   - RedundantN = 2 (N=4) or 3 (N=6)
   - CueType = 'R' or 'NR' (balanced)
   - R items share the same color, appear as adjacent singletons
   - Sequence: N singleton steps (mix of "R" and "U")
   - Grouping: 'Grouped' (spatially/temporally adjacent)

3. **GS (Grouped+Singleton)**
   - RedundantN = 2 (N=4) or 3 (N=6)
   - CueType = 'R' or 'NR' (balanced)
   - R items share the same color, appear together in one step
   - Sequence: (N-R+1) steps (1 group "G" + (N-R) singletons "U")
   - Grouping: 'Grouped'

### Trial Counts (per set size):
- **Baseline**: `floor(MainReps/2)` trials
- **RS**: `MainReps` trials (half R-cue, half NR-cue)
- **GS**: `MainReps` trials (half R-cue, half NR-cue)

**Total per set size**: `floor(MainReps/2) + 2*MainReps` trials

---

## Which Script Should You Use?

### Use **Original** (`TrialMatrixSeq3way`) if:
- You want **fixed spatial positions** (always same locations)
- You want **predictable presentation order** (index order)
- You need `NoiseLevel` column for noise manipulation
- You prefer simpler, more direct trial generation

### Use **Alternative** (`TrialMatrixSeq3way_ACW`) if:
- You want **randomized spatial rotation** per trial (reduces position-specific effects)
- You want **ACW presentation order** (more natural circular scanning)
- You want `RingStart` tracking for analysis
- You prefer base-table + inflation approach (more flexible for design changes)

---

## Design Rationale: Why ACW Rotation?

The ACW rotation approach solves a critical design conflict:

### The Problem
If R (redundant) items can appear in the first sequence interval and we force starting at a fixed location (e.g., 12 o'clock):
- R items may not be able to appear at the starting position
- The presentation sequence cannot smoothly progress ACW/CW
- The sequence must "leap" locations because redundant items occupy multiple spatial positions
- **Conflict**: "Always start at one location" vs "R items occupy multiple locations"

### The Solution (ACW Approach)
- **Don't force a starting presentation location**
- **Rotate the ring every trial** (`RingStart = randi(N)`) to randomize the starting location
- **Always let R items be spatially or temporally adjacent** (maintains adjacency constraints)
- **Benefits**:
  - ✅ Enough randomness: participants cannot predict upcoming items
  - ✅ Predictable location progression: smooth ACW sequence, no leaps
  - ✅ Avoids confounding: no unnecessary attentional shifts
  - ✅ R items can appear anywhere, including first position

This design balances randomization (unpredictable items) with predictability (smooth spatial progression), ensuring clean experimental data without position-specific confounds.

---

## Recommendation for NoisePilot_HomoInte

**Use the ACW version** (`TrialMatrixSeq3way_ACW`) because:
1. ✅ It solves the position conflict you identified
2. ✅ Provides smooth ACW progression without location leaps
3. ✅ Randomizes starting positions while maintaining adjacency
4. ✅ Now includes `NoiseLevel` column (added for noisy stimuli support)

The script has been updated in `NoisePilot_HomoInte.m` to use `TrialMatrixSeq3way_ACW`.


