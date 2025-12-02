# Visualization Plan for HomoInte Pilot Data

## Research Questions

1. **Main Hypothesis**: Does redundancy (homogeneous sets) improve precision compared to baseline?
2. **Integration Type**: Which integration type (Space, Time, Space+Time) benefits most?
3. **Set Size Effect**: Does precision differ between N=2 and N=6?
4. **Noise Effect**: Does noise level affect homogeneous sets differently than baseline?
5. **Interactions**: Are there interactions between these factors?

## Recommended Visualization Strategy

### Phase 1: Overview Plots (Main Effects)

#### 1.1 Precision - Main Effects
**Plot 1: Precision by Condition**
- Type: Bar plot or violin plot with individual points
- X-axis: Condition (Baseline, Homo_Space, Homo_Time, Homo_SpaceTime)
- Y-axis: Mean Precision (degrees, lower = better)
- Error bars: 95% CI or SEM
- Individual points: Show each session's mean
- **Purpose**: Overall condition comparison

**Plot 2: Precision by Set Size**
- Type: Bar plot
- X-axis: Set Size (N=2, N=6)
- Y-axis: Mean Precision
- Separate panels or colors for each condition
- **Purpose**: Set size effect

**Plot 3: Precision by Noise Level**
- Type: Bar plot
- X-axis: Noise Level (Low, High)
- Y-axis: Mean Precision
- Separate panels or colors for each condition
- **Purpose**: Noise effect

#### 1.2 RT - Main Effects
**Same structure as Precision plots but for ResponseTime**

---

### Phase 2: Interaction Plots (Critical Comparisons)

#### 2.1 Condition × Set Size Interaction
**Plot 4: Precision by Condition × Set Size**
- Type: Line plot or grouped bar plot
- X-axis: Condition
- Separate lines/bars: N=2 vs N=6
- Y-axis: Mean Precision
- **Key Comparison**: 
  - Baseline N=2 vs Homo N=6 (redundancy benefit)
  - Baseline N=6 vs Homo N=6 (same set size, redundancy effect)

#### 2.2 Condition × Noise Interaction
**Plot 5: Precision by Condition × Noise**
- Type: Line plot
- X-axis: Condition
- Separate lines: Low vs High noise
- Y-axis: Mean Precision
- **Key Comparison**: 
  - Does noise affect homogeneous sets differently?
  - Critical test: If homogeneous sets represent as single unit, noise should affect them less

#### 2.3 Set Size × Noise Interaction
**Plot 6: Precision by Set Size × Noise**
- Type: Line plot
- X-axis: Set Size
- Separate lines: Low vs High noise
- Separate panels: Each condition
- **Purpose**: Does noise effect depend on set size?

---

### Phase 3: Detailed Condition Comparisons

#### 3.1 Integration Type Comparison
**Plot 7: Precision by Integration Type**
- Type: Bar plot
- X-axis: Integration Type (Space, Time, Space+Time)
- Separate panels: Set Size (N=2, N=6)
- Separate colors: Noise Level
- **Purpose**: Which integration type benefits most?

#### 3.2 Baseline vs Homo Conditions
**Plot 8: Precision - Baseline vs Homo**
- Type: Scatter plot or bar plot
- X-axis: Baseline vs each Homo condition
- Y-axis: Mean Precision
- Separate panels: Set Size × Noise combinations
- **Purpose**: Direct redundancy benefit assessment

---

### Phase 4: Distribution and Individual Differences

#### 4.1 Distribution Plots
**Plot 9: Precision Distributions**
- Type: Violin plots or box plots
- X-axis: Condition
- Y-axis: Precision (all trials)
- Separate panels: Set Size × Noise
- **Purpose**: Check for outliers, distribution shape, variability

#### 4.2 Individual Session Trends
**Plot 10: Precision Across Sessions**
- Type: Line plot
- X-axis: Session (1-8)
- Y-axis: Mean Precision
- Separate lines: Each condition
- **Purpose**: Check for learning effects, session consistency

---

### Phase 5: RT Analysis

#### 5.1 RT Main Effects
**Same structure as Precision Phase 1**

#### 5.2 RT Interactions
**Same structure as Precision Phase 2**

#### 5.3 Precision-RT Relationship
**Plot 11: Precision vs RT**
- Type: Scatter plot
- X-axis: ResponseTime
- Y-axis: Precision
- Colors: Condition
- **Purpose**: Speed-accuracy tradeoff

---

## Recommended Plot Types

### For Summary Statistics:
1. **Bar plots with error bars**: Mean ± SEM/CI
2. **Line plots**: For interactions and trends
3. **Grouped bar plots**: For multiple factors

### For Distributions:
1. **Violin plots**: Show full distribution + summary stats
2. **Box plots**: Standard quartile representation
3. **Histograms**: For detailed distribution shape

### For Individual Data:
1. **Scatter plots**: Individual trials or session means
2. **Raincloud plots**: Combine distribution + individual points
3. **Line plots**: Individual sessions over time

---

## Statistical Annotations

- Add significance markers (***, **, *, ns) for pairwise comparisons
- Show p-values for main effects and interactions
- Indicate effect sizes (Cohen's d, η²)
- Mark critical comparisons (e.g., Baseline N=2 vs Homo N=6)

---

## Color Scheme Recommendations

- **Conditions**: 
  - Baseline: Gray/Black
  - Homo_Space: Blue
  - Homo_Time: Red
  - Homo_SpaceTime: Green/Purple
- **Set Size**: Different shades or line styles
- **Noise**: Different line types (solid vs dashed) or colors

---

## Implementation Priority

### High Priority (Core Questions):
1. Plot 1: Precision by Condition
2. Plot 4: Condition × Set Size Interaction
3. Plot 5: Condition × Noise Interaction
4. Plot 7: Integration Type Comparison

### Medium Priority (Detailed Analysis):
5. Plot 2-3: Set Size and Noise main effects
6. Plot 9: Distribution plots
7. RT equivalents of plots 1-4

### Low Priority (Exploratory):
8. Plot 10: Session trends
9. Plot 11: Precision-RT relationship
10. Plot 6: Set Size × Noise interaction

---

## Notes

- Precision is in degrees (circular error)
- Lower precision = better performance
- Consider using absolute precision (|Precision|) for some analyses
- Check for outliers and data quality issues first
- RT should be in seconds (check ResponseTime units)

