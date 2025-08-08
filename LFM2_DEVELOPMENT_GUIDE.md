# LFM2 Development Guide for Vera App

## Overview
This guide outlines the development process for integrating and optimizing LFM2 for the Vera personal finance assistant app. You'll be creating a test environment to determine optimal model parameters and system prompts for mobile deployment.

## System Components & Requirements

### 1. Transactions - CSV Processing & Categorization

**Purpose**: Parse raw CSV bank data and transform it into structured, categorized transactions

**LFM2 Tasks**:
- Extract transaction fields (date, amount, description, merchant)
- Deduplicate internal transfers: Identify and zero out transfers between user's own accounts (e.g., savings → checking should not count as income/expense, match debits and credits that cancel out)
- Categorize each transaction into predefined categories (e.g., Food & Dining, Transportation, Shopping, Bills & Utilities, Entertainment, Healthcare, Income)
- Clean and normalize merchant names
- Identify recurring transactions/subscriptions
- Flag unusual or potentially fraudulent transactions
- Detect inter-account transfers by matching amounts, dates, and descriptions across accounts

**Optimization Focus**: Accuracy in category assignment, handling diverse transaction description formats, speed for batch processing, intelligent transfer detection to avoid double-counting

### 2. Insights - Analysis & Visualization Data

**Purpose**: Analyze spending patterns and generate data for visualizations

**LFM2 Tasks**:
- Aggregate transactions by category, time period, and merchant
- Calculate spending trends and patterns
- Identify spending anomalies or notable changes
- Generate natural language insights (e.g., "Your dining expenses increased 30% this month")
- Prepare data structures for Sankey diagram (flow from income → categories → subcategories)
- Create month-over-month comparisons

**Optimization Focus**: Pattern recognition, statistical analysis, generating actionable insights rather than just data summaries

### 3. Budget Chat - Interactive Financial Assistant

**Purpose**: Conversational agent for budget optimization and financial advice

**LFM2 Tasks**:
- Understand user's financial goals and constraints
- Analyze current spending against proposed budgets
- Suggest realistic budget adjustments based on spending history
- Answer questions about spending patterns
- Provide personalized savings recommendations
- Negotiate budget allocations interactively

**Optimization Focus**: Conversational coherence, empathetic responses, practical and achievable recommendations, maintaining context across chat turns

### 4. Budget Summary - Visual Budget Planning

**Purpose**: Transform budget recommendations into visual, actionable format

**LFM2 Tasks**:
- Generate optimal budget allocation based on income and goals
- Create before/after budget comparisons
- Prioritize savings opportunities by impact
- Generate specific action items (e.g., "Cancel unused subscription X to save $15/month")
- Project future savings based on recommended changes
- Create data for budget flow visualizations

**Optimization Focus**: Clarity of recommendations, quantifiable impact metrics, visual data structure generation, prioritization of high-impact changes

## Development Process

### Step 1: Create Test Repository
1. Create a new GitHub repository called `vera-lfm2-test`
2. Initialize it with a basic iOS app structure using SwiftUI
3. Set minimum iOS deployment target to 15.0

### Step 2: Prepare Sample Data
1. Export a CSV file from your personal bank account (3-6 months of data recommended)
2. Sanitize the data if needed (you can anonymize merchant names while keeping patterns)
3. Place the CSV file in the project's resources folder
4. Create a simple CSV parser to load this data

### Step 3: Install LEAP SDK and LFM2
1. Add the LEAP SDK to your project via Swift Package Manager
2. Download and integrate different LFM2 model sizes to test:
   - Start with the smallest parameter model (e.g., 350M)
   - Test progressively larger models (500M, 700M, 1B)
   - Document memory usage and performance for each

### Step 4: Implement Basic Test Interface
1. Create a simple UI with four tabs matching the system components
2. Implement basic functionality for each:
   - **Transactions tab**: Load CSV, display raw and processed transactions
   - **Insights tab**: Show category summaries and basic statistics
   - **Budget Chat tab**: Simple chat interface for testing prompts
   - **Budget Summary tab**: Display generated budget recommendations

### Step 5: Mobile Testing & Model Selection
1. Build and deploy the app to your physical iPhone
2. Test each model size and measure:
   - App launch time
   - Processing time for 100 transactions
   - Memory usage (use Xcode Instruments)
   - Battery drain over 10 minutes of use
   - UI responsiveness during processing
3. Document the maximum model size that maintains:
   - < 3 second launch time
   - < 100ms per transaction processing
   - < 1GB memory usage
   - Smooth UI performance

### Step 6: System Prompt Optimization
Once you've identified the optimal model size:

1. **Transactions Prompt Testing**:
   - Create variations of categorization prompts
   - Test accuracy on your sample transactions
   - Measure false positive rate for transfer detection
   - Document which prompt formats work best

2. **Insights Prompt Testing**:
   - Test different prompt structures for pattern recognition
   - Evaluate quality of generated insights
   - Measure relevance and actionability of suggestions

3. **Budget Chat Prompt Testing**:
   - Test conversation flow and context retention
   - Evaluate quality of financial advice
   - Test edge cases (unrealistic budgets, conflicting goals)

4. **Budget Summary Prompt Testing**:
   - Test clarity of generated summaries
   - Evaluate prioritization logic
   - Measure accuracy of savings projections

### Step 7: Documentation
Create a results document containing:
1. Optimal model size for iPhone deployment
2. Performance benchmarks for chosen model
3. Best performing prompts for each component
4. Sample outputs demonstrating quality
5. Recommendations for production implementation

## Testing Checklist

- [ ] Repository created and iOS app initialized
- [ ] Sample CSV data prepared and imported
- [ ] LEAP SDK integrated successfully
- [ ] Multiple LFM2 model sizes tested on device
- [ ] Performance metrics documented
- [ ] Optimal model size identified
- [ ] System prompts created for all 4 components
- [ ] Prompt variations tested and optimized
- [ ] Transfer deduplication logic validated
- [ ] Results documented with recommendations

## Success Criteria

Your testing is complete when you can:
1. Run the app smoothly on an iPhone with real transaction data
2. Process 500+ transactions in under 30 seconds
3. Generate accurate categorizations (>90% accuracy)
4. Detect internal transfers with >95% accuracy
5. Produce meaningful insights and budget recommendations
6. Maintain conversation context in budget chat
7. Keep total app size under 1GB including model

## Deliverables

1. Test repository with working prototype
2. Performance benchmark report
3. Optimized system prompts for all 4 components
4. Recommendations document for production implementation
5. Sample outputs demonstrating LFM2 capabilities

Remember: The goal is to find the sweet spot between model capability and mobile performance, then optimize the prompts to maximize value for users within those constraints.