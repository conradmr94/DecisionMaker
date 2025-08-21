# DecisionMaker

A smart decision-making iOS app built with SwiftUI and SwiftData that helps you make choices using intelligent algorithms and preference learning.

## Overview

DecisionMaker is designed to solve the common problem of decision paralysis. Whether you're choosing where to eat, what movie to watch, or which task to tackle next, the app uses smart algorithms to help you make decisions while learning from your preferences over time.

## Features

### Core Decision Making
- **Quick Decision Mode**: Add options on the fly and get instant decisions
- **Smart Picker**: Uses preference scoring and adventurousness controls
- **Avoid Repetition**: Prevents choosing the same option multiple times in a row

### Preference Learning
- **Success/Failure Tracking**: Rate your choices to improve future decisions
- **Beta Distribution Scoring**: Advanced statistical modeling for preference learning
- **Context Awareness**: Tracks time of day and weekday patterns

### List Management
- **Save Decision Sets**: Create reusable lists for common decision scenarios
- **Persistent Storage**: All your lists and preferences are saved locally
- **Easy Management**: Edit, reorder, and delete options as needed

### Customization
- **Adventurousness Control**: Adjust from "No Adventure" to "Surprise Me"
- **Visual Feedback**: Haptic feedback and smooth animations during selection
- **Flexible Input**: Add options quickly with natural text input

## Technical Details

### Architecture
- **SwiftUI**: Modern declarative UI framework
- **SwiftData**: Persistent data storage with automatic sync
- **MVVM Pattern**: Clean separation of concerns

### Data Models
- `DecisionSet`: Collections of related choices
- `Choice`: Individual decision options
- `ChoicePref`: Preference tracking with success/failure counts
- `ChoiceLog`: Decision history with temporal context

### Smart Picker Algorithm
The app uses a sophisticated decision algorithm that combines:
- **Preference Scoring**: Beta distribution-based scoring from success/failure data
- **Temperature Control**: Adjustable randomness based on adventurousness setting
- **Uniform Mixing**: Balances preference with exploration
- **Softmax Sampling**: Probabilistic selection with controlled randomness

### Performance Features
- **Elimination of Recent Picks**: Prevents immediate repetition
- **Efficient Data Queries**: SwiftData integration for fast local storage
- **Smooth Animations**: Responsive UI with haptic feedback

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

1. Clone the repository
2. Open `DecisionMaker.xcodeproj` in Xcode
3. Select your target device or simulator
4. Build and run the project

## Usage

### Making a Quick Decision
1. Add options using the text field at the bottom
2. Adjust the adventurousness slider to your preference
3. Tap "Pick One" to get a decision
4. Accept the choice or request another option

### Managing Decision Sets
1. Use the "Lists" button in the top toolbar
2. Create new sets from your current options
3. Save frequently used decision scenarios
4. Access your saved lists anytime

### Learning Preferences
- Accept choices you're happy with to improve future picks
- Skip choices you don't want to reinforce negative preferences
- The app automatically tracks your success/failure patterns

## Development

The project follows iOS development best practices with:
- Clean SwiftUI architecture
- Comprehensive data modeling
- Efficient algorithms for decision making
- Local data persistence with SwiftData

## License

This project is open source and available under the MIT License.
