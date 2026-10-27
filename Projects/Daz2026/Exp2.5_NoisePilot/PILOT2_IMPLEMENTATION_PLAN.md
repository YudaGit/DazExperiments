# Pilot 2 Implementation Plan: Homogeneous Integration

## Design Summary

### Conditions:
1. **Baseline**: All unique items (R=0), N=2,6, Low/High noise, 60 trials each = 240 total
2. **Homo-Space**: All same hue (R=N), simultaneous, N=2,6, Low/High noise, 20 trials each = 80 total
3. **Homo-Time**: All same hue (R=N), sequential same location, N=2,6, Low/High noise, 20 trials each = 80 total
4. **Homo-Space+Time**: All same hue (R=N), sequential ACW different locations, N=2,6, Low/High noise, 20 trials each = 80 total

**Total: 480 trials**

### Key Requirements:
- Set sizes: N=2, N=6
- For homogeneous conditions: R = N (R=2 for N=2, R=6 for N=6)
- Noise levels: Low (K=50) and High (K=2)
- Baseline: R=0 (all unique)
- Homogeneous: All items same hue (R=N)
- Cue type: For homogeneous, use 'NR' (no meaningful cue distinction)

### Condition Structure:

| Condition | ItemN | RedundantN | NoiseLevel | CueType | Reps | Total |
|-----------|-------|------------|------------|---------|------|-------|
| Baseline | 2 | 0 | Low | NR | 60 | 60 |
| Baseline | 2 | 0 | High | NR | 60 | 60 |
| Baseline | 6 | 0 | Low | NR | 60 | 60 |
| Baseline | 6 | 0 | High | NR | 60 | 60 |
| Homo-Space | 2 | 2 | Low | NR | 20 | 20 |
| Homo-Space | 2 | 2 | High | NR | 20 | 20 |
| Homo-Space | 6 | 6 | Low | NR | 20 | 20 |
| Homo-Space | 6 | 6 | High | NR | 20 | 20 |
| Homo-Time | 2 | 2 | Low | NR | 20 | 20 |
| Homo-Time | 2 | 2 | High | NR | 20 | 20 |
| Homo-Time | 6 | 6 | Low | NR | 20 | 20 |
| Homo-Time | 6 | 6 | High | NR | 20 | 20 |
| Homo-Space+Time | 2 | 2 | Low | NR | 20 | 20 |
| Homo-Space+Time | 2 | 2 | High | NR | 20 | 20 |
| Homo-Space+Time | 6 | 6 | Low | NR | 20 | 20 |
| Homo-Space+Time | 6 | 6 | High | NR | 20 | 20 |

### Implementation Changes Needed:

1. **Function name**: Change to `TrialMatrixSeq3way_HomoInte`
2. **buildBase()**: Create base table with:
   - Baseline: N=2,6, R=0, Noise=Low/High, Cue=NR
   - Homo-Space: N=2,6, R=N, Noise=Low/High, Cue=NR
   - Homo-Time: N=2,6, R=N, Noise=Low/High, Cue=NR
   - Homo-Space+Time: N=2,6, R=N, Noise=Low/High, Cue=NR
3. **addSequenceOrderACW()**: Handle new conditions:
   - **Homo-Space**: Simultaneous presentation (all items in one interval)
   - **Homo-Time**: Sequential, all items at same location
   - **Homo-Space+Time**: Sequential ACW, different locations
4. **NoiseLevel**: Set based on condition (Low/High)
5. **Colors**: For homogeneous, all items same hue

### Design Structure:
- Need to add `NoiseLevel` to design structure or determine from condition
- For homogeneous: All items get same hue (R=N means all redundant)
- For baseline: All items unique hues

