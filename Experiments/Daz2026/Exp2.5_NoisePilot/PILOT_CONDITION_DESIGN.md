# Pilot Experiment Condition Design

## Overview
This document outlines the experimental conditions for testing redundant information integration across different dimensions (space, time, space+time) and homogeneous set conditions.

---

## Condition Structure

### 1. **Baseline** (Control)
- **Description**: All unique items, no redundancy
- **Set sizes**: N=4, N=6
- **Presentation**: Sequential (N intervals, one item per interval)
- **Integration type**: None (control condition)
- **Cue type**: NR (no redundant items to cue)
- **Trial N**: 80 trials each for set size 4 and 6

### 2. **Redundant Singletons - Temporal Integration**
- **Description**: R redundant items repeat across intervals, shown at the **SAME location**
- **Set sizes**: N=4 (R=2), N=6 (R=3).
- **Presentation**: Sequential (N intervals)
  - R items appear at the same spatial location across multiple intervals
  - Other items appear at different locations. Therefore, for set size 4 conditions, there should only be 3 possible locations for stimuli to appear in a trial, and only 4 for set size 6 ttrials in this condition. The important thing is to alway have even spacing between stimuli.
- **Integration type**: **Time only** (redundancy across temporal intervals, same spatial location)
- **Cue type**: R (cue redundant) or NR (cue non-redundant)
- **Example**: Items 1 and 2 are redundant, both shown at location A in intervals 1 and 2
- **Trial N**: 80 (40 for R and 40 for NR) trials each for set size 4 and 6

### 3. **Redundant Singletons - Temporal Spatial Integration**
- **Description**: R redundant items repeat across intervals, shown at **DIFFERENT locations** (ACW order)
- **Set sizes**: N=4 (R=2), N=6 (R=3)
- **Presentation**: Sequential (N intervals), ACW progression
  - R items appear as adjacent singletons in the ACW sequence
  - Each redundant item appears at a different spatial location
- **Integration type**: **Space + Time** (redundancy across temporal intervals AND spatial locations). Location wise, this differ from Temporal Integration condition trials, that the number of possible spatial locations should follow set size. Also need to ensure even spacing between stimuli
- **Cue type**: R (cue redundant) or NR (cue non-redundant)
- **Example**: Items 1 and 2 are redundant, shown at locations A and B in intervals 1 and 2 (ACW adjacent)
- **Trial N**: 80 (40 for R and 40 for NR) trials each for set size 4 and 6

### 4. **Redundant Grouped** (Space-Only Integration)
- **Description**: R redundant items shown together in **ONE interval** as a spatial group
- **Set sizes**: N=4 (R=2), N=6 (R=3)
- **Presentation**: Sequential (N-R+1 intervals)
  - One interval shows R redundant items together (spatial group)
  - Other intervals show unique items
- **Integration type**: **Space only** (redundancy within single temporal interval, multiple spatial locations)
- **Cue type**: R (cue redundant) or NR (cue non-redundant)
- **Example**: Items 1 and 2 are redundant, shown together in interval 1, other items shown separately
- **Trial N**: 80 (40 for R and 40 for NR) trials each for set size 4 and 6

So if we only consider the above conditions, that's 640 trials, without touching low/high noise stimuli manipulation.

**Alternative Option**: Simultaneous presentation (all items at once) - see discussion below.

From here below, I think can be a separate pilot. We need baseline 
conditions of all NR items in both low and high noise. Set size for this pilot should include 2 and 6. Trial number wise, set 2 low/high and set 6 low/high all need 60 trials, so that is 4x60 = 240

Then we need:

### 5. **Homogeneous Set - Space Only**
- **Description**: All items have the **same base hue**, shown **simultaneously** in one interval
- **Set sizes**: N=2, N=6
- **Noise**: Low, High. Noise is an important aspect of testing homogeneous redundancy set. We had data before showing that single item precision and set size 6 homogeneous redundancy set precision being the same. One explanation is ceiling, another is redundancy is represented as a single unit in memory. These two alternatives can be tested by pitting low high noise stimuli sets against each other.
- **Presentation**: **Single interval** (simultaneous)
  - All N items shown at once, all same hue
- **Integration type**: **Space only** (redundancy across spatial locations, single temporal interval). Make sure spatial locations are evenly spaced, and goes according to set size.
- **Cue type**: N/A (all items identical, cue any item)
- **Note**: Tests precision for homogeneous sets with spatial integration only
- **Trial N**: There won't be any NR cues due to no NR items in the set. So we need 20 trials each for set size 2 6 low/high. 20x4 = 80 total trials

### 6. **Homogeneous Set - Time Only**
- **Description**: All items have the **same base hue**, shown **sequentially at the SAME location**
- **Set sizes**: N=2, N=6
- **Presentation**: Sequential (N intervals)
  - Each interval shows one item at the same spatial location
  - All items have identical hue
- **Integration type**: **Time only** (redundancy across temporal intervals, same spatial location)
- **Cue type**: N/A (all items identical, cue any item)
- **Note**: Tests precision for homogeneous sets with temporal integration only.
- **Trial N**: There won't be any NR cues due to no NR items in the set. So we need 20 trials each for set size 2 6 low/high. 20x4 = 80 total trials

### 7. **Homogeneous Set - Space+Time**
- **Description**: All items have the **same base hue**, shown **sequentially at DIFFERENT locations** (ACW order)
- **Set sizes**: N=2, N=6
- **Presentation**: Sequential (N intervals), ACW progression
  - Each interval shows one item at a different spatial location (ACW)
  - All items have identical hue
- **Integration type**: **Space + Time** (redundancy across temporal intervals AND spatial locations)
- **Cue type**: N/A (all items identical, cue any item)
- **Note**: Tests precision for homogeneous sets with both spatial and temporal integration
- **Trial N**: There won't be any NR cues due to no NR items in the set. So we need 20 trials each for set size 2 6 low/high. 20x4 = 80 total trials

When we do homogeneous set conditions like the above, the total homogeneous set trial number will match that of the baseline condition described above.
---

## Condition Summary Table

| Condition | Redundancy | Presentation | Integration Type | Cue Type | Notes |
|-----------|------------|--------------|------------------|----------|-------|
| Baseline | None | Sequential (N intervals) | None | NR | Control |
| RS-Type A | R items | Sequential, same location | Time only | R/NR | New condition |
| RS-Type B | R items | Sequential, ACW (different locations) | Space+Time | R/NR | Current RS |
| Redundant Grouped | R items | Sequential, grouped in 1 interval | Space only | R/NR | Current GS |
| Homo-Space | All same hue | Simultaneous (1 interval) | Space only | N/A | New condition |
| Homo-Time | All same hue | Sequential, same location | Time only | N/A | New condition |
| Homo-Space+Time | All same hue | Sequential, ACW (different locations) | Space+Time | N/A | New condition |

---

## Design Questions & Decisions

### Q1: Simultaneous vs. Grouped for Space-Only Integration?

**Option A: Redundant Grouped (current GS)**
- Pros: Consistent with sequential presentation format
- Pros: Can compare grouped vs. singleton presentation
- Cons: Still requires multiple intervals (N-R+1)

**Option B: Simultaneous Presentation**
- Pros: Pure space-only integration (single temporal point)
- Pros: Faster trials
- Cons: Different presentation format may introduce confounds
- Cons: Requires separate presentation code path

**Recommendation**: Start with **Redundant Grouped** (Option A) for consistency, but consider adding simultaneous as a separate condition if needed.

### Q2: Homogeneous Set Conditions - Full Redundancy?

For homogeneous conditions, should R = N (full redundancy) or keep R = 2/3?

**Recommendation**: Use **R = N** (full redundancy) for homogeneous conditions to test pure integration without non-redundant items.

### Q3: Cue Type for Homogeneous Conditions?

Since all items are identical in homogeneous conditions, cueing is less meaningful.

**Recommendation**: 
- For analysis: Can treat as "cue any" or randomly assign cue type
- For implementation: Use 'NR' as default, or add 'Any' cue type

---

## Trial Balancing Proposal

### Per Set Size (N=4 or N=6):

| Condition | Reps | Cue Balance | Total Trials |
|-----------|------|-------------|--------------|
| Baseline | MainReps/2 | NR only | MainReps/2 |
| RS-Type A | MainReps | R:NR = 1:1 | MainReps |
| RS-Type B | MainReps | R:NR = 1:1 | MainReps |
| Redundant Grouped | MainReps | R:NR = 1:1 | MainReps |
| Homo-Space | MainReps/2 | N/A | MainReps/2 |
| Homo-Time | MainReps/2 | N/A | MainReps/2 |
| Homo-Space+Time | MainReps/2 | N/A | MainReps/2 |

**Total per set size**: `MainReps/2 + 3*MainReps + 3*MainReps/2 = 5.5*MainReps`

**Example with MainReps = 50**:
- Baseline: 25 trials
- RS-Type A: 50 trials (25 R-cue, 25 NR-cue)
- RS-Type B: 50 trials (25 R-cue, 25 NR-cue)
- Redundant Grouped: 50 trials (25 R-cue, 25 NR-cue)
- Homo-Space: 25 trials
- Homo-Time: 25 trials
- Homo-Space+Time: 25 trials
- **Total**: 275 trials per set size

**For 2 set sizes (N=4, N=6)**: 550 total trials

### Alternative Balancing (More Balanced):

| Condition | Reps | Cue Balance | Total Trials |
|-----------|------|-------------|--------------|
| Baseline | MainReps | NR only | MainReps |
| RS-Type A | MainReps | R:NR = 1:1 | MainReps |
| RS-Type B | MainReps | R:NR = 1:1 | MainReps |
| Redundant Grouped | MainReps | R:NR = 1:1 | MainReps |
| Homo-Space | MainReps | N/A | MainReps |
| Homo-Time | MainReps | N/A | MainReps |
| Homo-Space+Time | MainReps | N/A | MainReps |

**Total per set size**: `7*MainReps`

**Example with MainReps = 50**: 350 trials per set size, **700 total trials**

---

## Implementation Considerations

### New Condition Types Needed:

1. **RS-Type A** (Time-only, same location)
   - Requires: Same location assignment for redundant items
   - Sequence: R items appear at same location across intervals

2. **Homogeneous Conditions**
   - Requires: All items same hue (R = N)
   - Space-only: Single interval presentation
   - Time-only: Sequential, same location
   - Space+Time: Sequential, ACW (different locations)

3. **Simultaneous Presentation** (if chosen)
   - Requires: New presentation code path
   - All items shown at once in single interval

### Code Structure Changes:

- Add new condition types: `'RS_TimeOnly'`, `'Homo_Space'`, `'Homo_Time'`, `'Homo_SpaceTime'`
- Modify `buildBase()` to include new conditions
- Modify `addSequenceOrderACW()` to handle:
  - Same-location redundant items (RS-Type A)
  - Homogeneous sets (R = N)
  - Simultaneous presentation (if chosen)

---

## Recommended Next Steps

1. **Confirm condition structure** - Review and approve the 7 conditions
2. **Decide on trial balancing** - Choose between balanced (7×MainReps) or reduced (5.5×MainReps)
3. **Decide on simultaneous presentation** - Include or exclude for space-only integration
4. **Clarify homogeneous cueing** - How to handle cue type for identical items
5. **Update trial matrix script** - Implement new condition types
6. **Update presentation code** - Handle simultaneous presentation if included

---

## Questions for Discussion

1. **Trial count**: Is 550-700 trials per participant acceptable, or should we reduce?
2. **Simultaneous presentation**: Include as separate condition or stick with grouped?
3. **Homogeneous conditions**: Should these be separate blocks or interleaved?
4. **Cue type for homogeneous**: How to handle cueing when all items identical?
5. **Practice trials**: Should practice include all condition types or subset?

